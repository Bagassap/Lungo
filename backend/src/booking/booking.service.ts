import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { InjectRepository, InjectDataSource } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { Ride } from './entities/ride.entity';
import { RideStatus } from './enums/ride-status.enum';
import { CreateRideDto } from './dto/create-ride.dto';
import { UpdateRideStatusDto } from './dto/update-ride-status.dto';
import { TrackingService } from '../tracking/tracking.service';
import { TrackingGateway } from '../tracking/tracking.gateway';
import { FcmService } from './fcm.service';
import { TariffService } from '../tariff/tariff.service';
import { ZonaService } from '../tariff/zona.service';
import { WalletService } from '../wallet/wallet.service';
import { User } from '../users/entities/user.entity';
import { Driver } from '../drivers/entities/driver.entity';
import { UserNotification } from '../users/entities/user_notification.entity';

const VALID_TRANSITIONS: Record<RideStatus, RideStatus[]> = {
  [RideStatus.SEARCHING]: [RideStatus.ACCEPTED, RideStatus.CANCELLED],
  [RideStatus.ACCEPTED]: [RideStatus.PICKUP, RideStatus.CANCELLED],
  [RideStatus.PICKUP]: [RideStatus.ONGOING, RideStatus.CANCELLED],
  [RideStatus.ONGOING]: [RideStatus.DONE],
  [RideStatus.DONE]: [],
  [RideStatus.CANCELLED]: [],
};

@Injectable()
export class BookingService {
  constructor(
    @InjectRepository(Ride)
    private readonly rideRepo: Repository<Ride>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Driver)
    private readonly driverRepo: Repository<Driver>,
    @InjectRepository(UserNotification)
    private readonly notifRepo: Repository<UserNotification>,
    @InjectDataSource()
    private readonly dataSource: DataSource,
    private readonly trackingService: TrackingService,
    private readonly trackingGateway: TrackingGateway,
    private readonly fcmService: FcmService,
    private readonly tariffService: TariffService,
    private readonly zonaService: ZonaService,
    private readonly walletService: WalletService,
  ) {}

  async createRide(dto: CreateRideDto): Promise<Ride> {
    const ride = this.rideRepo.create({
      passengerId: dto.passengerId,
      originLat: dto.originLat,
      originLng: dto.originLng,
      destinationLat: dto.destinationLat,
      destinationLng: dto.destinationLng,
      originAddress: dto.originAddress ?? null,
      destinationAddress: dto.destinationAddress ?? null,
      status: RideStatus.SEARCHING,
    });
    await this.rideRepo.save(ride);

    const nearbyDrivers = await this.trackingService.getNearbyDrivers(
      dto.originLat,
      dto.originLng,
      3,
    );

    const distKm = Math.round(
      this.haversine(dto.originLat, dto.originLng, dto.destinationLat, dto.destinationLng) * 10,
    ) / 10;

    const zonaFare = this.zonaService.hitungTarif(distKm, dto.originLat, dto.originLng);
    ride.zona         = zonaFare.zona;
    ride.fareDriver   = zonaFare.fareDriver;
    ride.farePassenger = zonaFare.farePassenger;
    ride.feeLungo     = zonaFare.feeLungo;
    await this.rideRepo.save(ride);

    const passenger = await this.userRepo.findOne({ where: { id: dto.passengerId } });

    const ridePayload = {
      rideId:             ride.id,
      originLat:          dto.originLat,
      originLng:          dto.originLng,
      destinationLat:     dto.destinationLat,
      destinationLng:     dto.destinationLng,
      estimatedFare:      zonaFare.farePassenger,
      distanceKm:         distKm,
      passengerName:      passenger?.name || passenger?.phone || 'Penumpang',
      passengerRating:    4.8,
      originAddress:      dto.originAddress ?? '',
      destinationAddress: dto.destinationAddress ?? '',
    };

    console.log('[BOOKING] passenger query result:', JSON.stringify(passenger));
    console.log('[BOOKING] FCM payload:', JSON.stringify(ridePayload));
    await this.fcmService.notifyNearbyDrivers(
      nearbyDrivers.map((d) => d.driverId),
      ridePayload,
    );

    this.trackingGateway.broadcastNewRide(
      ridePayload,
      nearbyDrivers.map((d) => d.driverId),
    );

    this.notifRepo.save(this.notifRepo.create({
      userId: dto.passengerId,
      title: 'Mencari Driver',
      body: 'Kami sedang mencari driver terdekat untuk kamu.',
      type: 'ride',
    }));

    return ride;
  }

  async acceptRide(rideId: string, driverId: string): Promise<Ride> {
    const ride = await this.dataSource.transaction(async (em) => {
      const locked = await em.findOne(Ride, {
        where: { id: rideId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!locked) throw new NotFoundException(`Ride ${rideId} tidak ditemukan`);
      this.assertTransition(locked.status, RideStatus.ACCEPTED);

      locked.status = RideStatus.ACCEPTED;
      locked.driverId = driverId;
      return em.save(Ride, locked);
    });

    const [driverUser, driverEntity] = await Promise.all([
      this.userRepo.findOne({ where: { id: driverId } }),
      this.driverRepo.findOne({ where: { userId: driverId } }),
    ]);

    this.trackingGateway.notifyRideAccepted({
      rideId,
      driverId,
      driverName: driverUser?.name ?? undefined,
      driverPlate: driverEntity?.vehiclePlate ?? undefined,
      driverRating: driverEntity?.rating ? Number(driverEntity.rating) : undefined,
      driverPhone: driverUser?.phone ?? undefined,
    });

    this.notifRepo.save(this.notifRepo.create({
      userId: ride.passengerId,
      title: 'Driver Ditemukan',
      body: `${driverUser?.name ?? 'Driver'} sedang menuju lokasimu.`,
      type: 'ride',
    }));

    this.fcmService.notifyPassenger(
      ride.passengerId,
      'Driver Ditemukan! 🏍️',
      `${driverUser?.name ?? 'Driver'} sedang menuju lokasimu.`,
      { rideId, type: 'DRIVER_ACCEPTED' },
    );

    return ride;
  }

  async updateStatus(dto: UpdateRideStatusDto): Promise<Ride> {
    const ride = await this.findById(dto.rideId!);
    this.assertTransition(ride.status, dto.status);

    ride.status = dto.status;
    if (dto.driverId) ride.driverId = dto.driverId;
    const saved = await this.rideRepo.save(ride);

    this.trackingGateway.notifyRideStatusChanged(saved.id, dto.status);

    if (dto.status === RideStatus.PICKUP) {
      this.notifRepo.save(this.notifRepo.create({
        userId: saved.passengerId,
        title: 'Driver Menuju Lokasimu',
        body: 'Driver sudah tiba dan sedang menuju titik jemput.',
        type: 'ride',
      }));
      this.fcmService.notifyPassenger(
        saved.passengerId,
        'Driver Menuju Lokasimu 🛵',
        'Driver sudah tiba dan sedang menuju titik jemput.',
        { rideId: saved.id, type: 'DRIVER_PICKUP' },
      );
    } else if (dto.status === RideStatus.ONGOING) {
      this.notifRepo.save(this.notifRepo.create({
        userId: saved.passengerId,
        title: 'Perjalanan Dimulai',
        body: 'Nikmati perjalananmu bersama Lungo!',
        type: 'ride',
      }));
      this.fcmService.notifyPassenger(
        saved.passengerId,
        'Perjalanan Dimulai 🚀',
        'Nikmati perjalananmu bersama Lungo!',
        { rideId: saved.id, type: 'RIDE_STARTED' },
      );
    }

    return saved;
  }

  async completeRide(rideId: string): Promise<{ ride: Ride; fare: number }> {
    const ride = await this.findById(rideId);
    this.assertTransition(ride.status, RideStatus.DONE);

    const distanceKm = this.haversine(
      Number(ride.originLat),
      Number(ride.originLng),
      Number(ride.destinationLat),
      Number(ride.destinationLng),
    );

    const zonaFare    = this.zonaService.hitungTarif(distanceKm, Number(ride.originLat), Number(ride.originLng));
    const fareDriver  = zonaFare.fareDriver;
    const fare        = zonaFare.farePassenger;

    ride.status        = RideStatus.DONE;
    ride.distanceKm    = Math.round(distanceKm * 1000) / 1000;
    ride.fare          = fare;
    ride.zona          = zonaFare.zona;
    ride.fareDriver    = fareDriver;
    ride.farePassenger = fare;
    ride.feeLungo      = zonaFare.feeLungo;
    await this.rideRepo.save(ride);

    // Emit WebSocket ke room ride agar passenger detect DONE (fallback dari socket endRide)
    this.trackingGateway.server.to(`ride:${rideId}`).emit('rideEnded', {
      rideId,
      distanceKm: ride.distanceKm,
      finalFare: fare,
      fareDriver,
      feeLungo: zonaFare.feeLungo,
    });
    this.trackingGateway.notifyRideStatusChanged(rideId, 'DONE', {
      distanceKm: ride.distanceKm,
      finalFare: fare,
      fareDriver,
    });

    if (ride.driverId) {
      await this.driverRepo
        .createQueryBuilder()
        .update(Driver)
        .set({ totalRides: () => '"totalRides" + 1' })
        .where('userId = :uid', { uid: ride.driverId })
        .execute();

      try {
        await this.walletService.credit(
          ride.driverId,
          fareDriver,
          `Pendapatan trip — Rp ${fareDriver.toLocaleString('id-ID')}`,
          ride.id,
        );
      } catch (_) {  }

      this.notifRepo.save(this.notifRepo.create({
        userId: ride.driverId,
        title: 'Perjalanan Selesai',
        body: `Kamu mendapat Rp ${fareDriver.toLocaleString('id-ID')}.`,
        type: 'ride',
      }));
      this.fcmService.notifyDriver(
        ride.driverId,
        'Perjalanan Selesai ✅',
        `Kamu mendapat Rp ${fareDriver.toLocaleString('id-ID')}.`,
        { rideId: ride.id, type: 'DRIVER_TRIP_DONE', fare: String(fareDriver) },
      );
    }

    if (ride.passengerId) {
      this.notifRepo.save(this.notifRepo.create({
        userId: ride.passengerId,
        title: 'Perjalanan Selesai',
        body: `Kamu telah tiba. Tarif: Rp ${fare.toLocaleString('id-ID')}.`,
        type: 'ride',
      }));
      this.fcmService.notifyPassenger(
        ride.passengerId,
        'Perjalanan Selesai ✅',
        `Kamu telah tiba. Tarif: Rp ${fare.toLocaleString('id-ID')}.`,
        { rideId: ride.id, type: 'RIDE_DONE', fare: String(fare) },
      );
    }

    try {
      const passengerBalance = await this.walletService.getBalance(ride.passengerId);
      if (passengerBalance.balance >= fare) {
        await this.walletService.debit(
          ride.passengerId,
          fare,
          `Pembayaran trip — Rp ${fare.toLocaleString('id-ID')}`,
          ride.id,
        );
      }
    } catch (_) {  }

    return { ride, fare };
  }

  async cancelRide(rideId: string): Promise<Ride> {
    const ride = await this.findById(rideId);
    this.assertTransition(ride.status, RideStatus.CANCELLED);

    ride.status = RideStatus.CANCELLED;
    const saved = await this.rideRepo.save(ride);
    this.trackingGateway.notifyRideCancelled(rideId);

    if (saved.passengerId) {
      this.notifRepo.save(this.notifRepo.create({
        userId: saved.passengerId,
        title: 'Perjalanan Dibatalkan',
        body: 'Perjalananmu telah dibatalkan. Coba cari ojek lagi.',
        type: 'ride',
      }));
      this.fcmService.notifyPassenger(
        saved.passengerId,
        'Perjalanan Dibatalkan ❌',
        'Perjalananmu telah dibatalkan. Coba cari ojek lagi.',
        { rideId, type: 'RIDE_CANCELLED' },
      );
    }

    if (saved.driverId) {
      this.notifRepo.save(this.notifRepo.create({
        userId: saved.driverId,
        title: 'Perjalanan Dibatalkan',
        body: 'Penumpang membatalkan perjalanan.',
        type: 'ride',
      }));
      this.fcmService.notifyDriver(
        saved.driverId,
        'Perjalanan Dibatalkan ❌',
        'Penumpang membatalkan perjalanan.',
        { rideId, type: 'RIDE_CANCELLED' },
      );
    }

    return saved;
  }

  async rateRide(rideId: string, passengerId: string, rating: number): Promise<{ message: string }> {
    if (rating < 1 || rating > 5) throw new BadRequestException('Rating harus antara 1-5');

    const ride = await this.findById(rideId);
    if (ride.passengerId !== passengerId)
      throw new BadRequestException('Kamu bukan penumpang di perjalanan ini');
    if (ride.status !== RideStatus.DONE)
      throw new BadRequestException('Hanya perjalanan yang selesai yang bisa diberi rating');
    if (ride.passengerRating !== null)
      return { message: 'Rating sudah diberikan sebelumnya' };

    ride.passengerRating = rating;
    await this.rideRepo.save(ride);

    if (ride.driverId) {
      const allRatings = await this.rideRepo
        .createQueryBuilder('r')
        .select('AVG(r.passengerRating)', 'avg')
        .where('r.driverId = :uid AND r.passengerRating IS NOT NULL', { uid: ride.driverId })
        .getRawOne<{ avg: string }>();

      const avg = allRatings?.avg ? Math.round(Number(allRatings.avg) * 100) / 100 : rating;

      await this.driverRepo
        .createQueryBuilder()
        .update(Driver)
        .set({ rating: avg })
        .where('userId = :uid', { uid: ride.driverId })
        .execute();
    }

    return { message: 'Rating berhasil disimpan' };
  }

  async getRide(rideId: string): Promise<any> {
    const ride = await this.findById(rideId);
    const result: any = { ...ride };

    if (ride.driverId) {
      const [driverUser, driverProfile] = await Promise.all([
        this.userRepo.findOne({ where: { id: ride.driverId } }),
        this.driverRepo.findOne({ where: { userId: ride.driverId } }),
      ]);
      if (driverUser) {
        result.driver = {
          name:         driverUser.name ?? '',
          phone:        driverUser.phone ?? '',
          vehiclePlate: driverProfile?.vehiclePlate ?? '',
          rating:       driverProfile?.rating ?? 5.0,
        };
      }
    }

    if (ride.passengerId) {
      const passengerUser = await this.userRepo.findOne({ where: { id: ride.passengerId } });
      if (passengerUser) {
        result.passenger = { name: passengerUser.name ?? '' };
      }
    }

    return result;
  }

  async getRideHistory(
    userId: string,
    status?: string,
    page = 1,
    limit = 10,
  ) {
    const qb = this.rideRepo
      .createQueryBuilder('ride')
      .where('ride.passengerId = :userId', { userId })
      .orderBy('ride.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit);

    if (status) {
      const up = status.toUpperCase();
      const berlangsung = [
        RideStatus.SEARCHING,
        RideStatus.ACCEPTED,
        RideStatus.PICKUP,
        RideStatus.ONGOING,
      ];
      if (up === 'BERLANGSUNG') {
        qb.andWhere('ride.status IN (:...statuses)', { statuses: berlangsung });
      } else if (up === 'SELESAI') {
        qb.andWhere('ride.status = :s', { s: RideStatus.DONE });
      } else if (up === 'DIBATALKAN') {
        qb.andWhere('ride.status = :s', { s: RideStatus.CANCELLED });
      }
    }

    const rides = await qb.getMany();
    return rides.map((ride) => {
      const distKm =
        Number(ride.distanceKm) ||
        Math.round(
          this.haversine(
            Number(ride.originLat),
            Number(ride.originLng),
            Number(ride.destinationLat),
            Number(ride.destinationLng),
          ) * 10,
        ) / 10;
      return {
        id: ride.id,
        from: this._coordLabel(Number(ride.originLat), Number(ride.originLng)),
        to: this._coordLabel(Number(ride.destinationLat), Number(ride.destinationLng)),
        status: ride.status,
        fare: Number(ride.fare ?? 0),
        distanceKm: distKm,
        durationMin: Math.max(1, Math.round(distKm * 3)),
        createdAt: ride.createdAt,
      };
    });
  }

  async getRideStats(userId: string) {
    const totalTrips = await this.rideRepo.count({
      where: { passengerId: userId, status: RideStatus.DONE },
    });
    const raw = await this.rideRepo
      .createQueryBuilder('ride')
      .select('SUM(ride.fare)', 'totalSpent')
      .where('ride.passengerId = :userId', { userId })
      .andWhere('ride.status = :status', { status: RideStatus.DONE })
      .getRawOne<{ totalSpent: string | null }>();
    return {
      totalTrips,
      totalSpent: raw?.totalSpent ? Math.round(Number(raw.totalSpent)) : 0,
      avgRating: 4.9,
    };
  }

  private _coordLabel(lat: number, lng: number): string {
    const latStr = `${Math.abs(lat).toFixed(3)}°${lat < 0 ? 'S' : 'N'}`;
    const lngStr = `${Math.abs(lng).toFixed(3)}°${lng < 0 ? 'W' : 'E'}`;
    return `${latStr}, ${lngStr}`;
  }

  private async findById(id: string): Promise<Ride> {
    const ride = await this.rideRepo.findOne({ where: { id } });
    if (!ride) throw new NotFoundException(`Ride ${id} tidak ditemukan`);
    return ride;
  }

  private assertTransition(from: RideStatus, to: RideStatus): void {
    const allowed = VALID_TRANSITIONS[from];
    if (!allowed.includes(to)) {
      throw new BadRequestException(
        `Transisi tidak valid: ${from} → ${to}. Diizinkan: [${allowed.join(', ') || 'tidak ada'}]`,
      );
    }
  }

  private haversine(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}
