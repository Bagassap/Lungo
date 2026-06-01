import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { Driver } from './entities/driver.entity';
import { User } from '../users/entities/user.entity';
import { Ride } from '../booking/entities/ride.entity';
import { RideStatus } from '../booking/enums/ride-status.enum';
import { UpdateDriverDto } from './dto/update-driver.dto';
import { ToggleOnlineDto } from './dto/toggle-online.dto';
import { DriverSubmitRegistrationDto } from './dto/driver-submit-registration.dto';
import { RedisService } from '../tracking/redis.service';
import { AdminNotification } from '../admin/entities/admin_notification.entity';

@Injectable()
export class DriversService {
  constructor(
    @InjectRepository(Driver)
    private readonly driverRepo: Repository<Driver>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Ride)
    private readonly rideRepo: Repository<Ride>,
    @InjectRepository(AdminNotification)
    private readonly adminNotifRepo: Repository<AdminNotification>,
    private readonly redisService: RedisService,
  ) {}

  async getProfile(userId: string) {
    const driver = await this.findByUserId(userId);
    const user = await this.userRepo.findOne({ where: { id: userId } });
    return { ...driver, user };
  }

  async updateProfile(userId: string, dto: UpdateDriverDto) {
    const driver = await this.findByUserId(userId);
    Object.assign(driver, dto);
    return this.driverRepo.save(driver);
  }

  async toggleOnline(userId: string, dto: ToggleOnlineDto) {
    const driver = await this.findByUserId(userId);
    driver.isOnline = dto.isOnline;
    await this.driverRepo.save(driver);

    if (dto.isOnline) {
      await this.redisService.setDriverLocation(userId, dto.latitude, dto.longitude);
    } else {
      await this.redisService.deleteDriverLocation(userId);
    }

    return { isOnline: driver.isOnline, driverId: driver.id, userId };
  }

  async updateFcmToken(userId: string, fcmToken: string) {
    await this.driverRepo.update({ userId }, { fcmToken });
    return { ok: true };
  }

  async uploadDocument(userId: string, type: 'ktp' | 'sim', fileUrl: string) {
    const driver = await this.findByUserId(userId);
    if (type === 'ktp') driver.ktpPhotoUrl = fileUrl;
    else driver.simPhotoUrl = fileUrl;
    return this.driverRepo.save(driver);
  }

  async submitRegistration(
    userId: string,
    dto: DriverSubmitRegistrationDto,
    files: {
      ktpUrl?: string;
      simUrl?: string;
      bpkbUrl?: string;
      stnkUrl?: string;
    },
  ) {
    let driver = await this.driverRepo.findOne({ where: { userId } });

    if (!driver) {
      driver = this.driverRepo.create({
        userId,
        vehicleType: dto.vehicleType ?? 'MOTOR',
        vehiclePlate: dto.vehiclePlate ?? '',
        registrationStatus: 'PENDING',
      });
    }

    driver.vehicleType  = dto.vehicleType  ?? driver.vehicleType;
    driver.vehiclePlate = dto.vehiclePlate ?? driver.vehiclePlate;
    driver.birthPlace   = dto.birthPlace;
    driver.birthDate    = dto.birthDate ? new Date(dto.birthDate) : null;
    driver.address      = dto.address;

    if (files.ktpUrl)  driver.ktpPhotoUrl  = files.ktpUrl;
    if (files.simUrl)  driver.simPhotoUrl  = files.simUrl;
    if (files.bpkbUrl) driver.bpkbPhotoUrl = files.bpkbUrl;
    if (files.stnkUrl) driver.stnkPhotoUrl = files.stnkUrl;

    driver.registrationStatus = 'PAYMENT_PENDING';
    await this.driverRepo.save(driver);

    const user = await this.userRepo.findOne({ where: { id: userId }, select: ['name', 'phone'] });
    await this.adminNotifRepo.save(
      this.adminNotifRepo.create({
        type: 'NEW_DRIVER_REGISTRATION',
        title: 'Pendaftaran Driver Baru',
        body: `${user?.name ?? 'Driver'} (${user?.phone ?? '-'}) telah submit dokumen dan menunggu verifikasi`,
        targetId: driver.id,
      }),
    );

    const qrisData =
      '00020101021226580014ID.CO.LUNGO.WWW011893600914001234560209123456780303UBE52044815' +
      `530336054050000055802ID5910LungoApp6015BandungIndonesia6105401166304ABCD`;

    return {
      success: true,
      qrisData,
      amount: 50000,
      driverId: driver.id,
      message: 'Scan QRIS untuk menyelesaikan pembayaran pendaftaran driver',
      instructions: [
        'Buka aplikasi mobile banking atau dompet digital kamu',
        'Pilih menu Scan QRIS',
        'Scan kode QR di bawah ini',
        'Masukkan nominal Rp 50.000',
        'Konfirmasi pembayaran',
        'Tekan tombol "Saya Sudah Bayar" setelah selesai',
      ],
      bankTransfer: {
        bankName: 'BCA',
        accountNumber: '1234567890',
        accountName: 'PT Lungo Indonesia',
        amount: 50000,
        note: `DRIVER-${userId.slice(0, 8).toUpperCase()}`,
      },
    };
  }

  async confirmPayment(userId: string) {
    const driver = await this.findByUserId(userId);
    driver.registrationStatus = 'REVIEW';
    await this.driverRepo.save(driver);
    return {
      success: true,
      message: 'Pembayaran dikonfirmasi! Akun driver kamu sedang dalam proses review. Estimasi 1x24 jam.',
      registrationStatus: 'REVIEW',
    };
  }

  async getRegistrationStatus(userId: string) {
    const driver = await this.driverRepo.findOne({ where: { userId } });
    if (!driver) {
      return { registrationStatus: 'NOT_STARTED', isComplete: false };
    }

    const isComplete =
      !!driver.birthPlace &&
      !!driver.address &&
      !!driver.ktpPhotoUrl &&
      !!driver.simPhotoUrl &&
      !!driver.bpkbPhotoUrl &&
      !!driver.stnkPhotoUrl;

    return {
      registrationStatus: driver.registrationStatus,
      isComplete,
      driver: {
        vehicleType:  driver.vehicleType,
        vehiclePlate: driver.vehiclePlate,
        birthPlace:   driver.birthPlace,
        birthDate:    driver.birthDate,
        address:      driver.address,
        hasKtp:       !!driver.ktpPhotoUrl,
        hasSim:       !!driver.simPhotoUrl,
        hasBpkb:      !!driver.bpkbPhotoUrl,
        hasStnk:      !!driver.stnkPhotoUrl,
      },
    };
  }

  async getDriverStats(userId: string) {
    const driver = await this.findByUserId(userId);
    const allRides = await this.rideRepo.find({ where: { driverId: userId } });
    const completed = allRides.filter((r) => r.status === RideStatus.DONE);

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const weekStart = new Date();
    weekStart.setDate(weekStart.getDate() - 7);
    weekStart.setHours(0, 0, 0, 0);

    const todayCompleted = completed.filter((r) => r.createdAt >= todayStart);
    const weekCompleted = completed.filter((r) => r.createdAt >= weekStart);

    const totalEarnings = completed.reduce((sum, r) => sum + Number(r.fare ?? 0), 0);
    const todayEarnings = todayCompleted.reduce((sum, r) => sum + Number(r.fare ?? 0), 0);
    const weeklyEarnings = weekCompleted.reduce((sum, r) => sum + Number(r.fare ?? 0), 0);
    const totalDistanceKm = completed.reduce((sum, r) => sum + Number(r.distanceKm ?? 0), 0);

    return {
      totalRides: driver.totalRides,
      totalTrips: completed.length,
      rating: Number(driver.rating),
      completedRides: completed.length,
      totalEarnings: Math.round(totalEarnings),
      todayTrips: todayCompleted.length,
      todayEarnings: Math.round(todayEarnings),
      weeklyEarnings: Math.round(weeklyEarnings),
      totalDistanceKm: Math.round(totalDistanceKm * 10) / 10,
    };
  }

  async getActivityStats(userId: string) {
    const rides = await this.rideRepo.find({ where: { driverId: userId } });
    const completed = rides.filter((r) => r.status === RideStatus.DONE);
    const cancelled = rides.filter((r) => r.status === RideStatus.CANCELLED);
    const totalEarnings = completed.reduce((s, r) => s + Number(r.fare ?? 0), 0);
    const totalDistanceKm = completed.reduce((s, r) => s + Number(r.distanceKm ?? 0), 0);
    return {
      totalRides:       rides.length,
      completedRides:   completed.length,
      cancelledRides:   cancelled.length,
      totalEarnings:    Math.round(totalEarnings),
      totalDistanceKm:  Math.round(totalDistanceKm * 10) / 10,
    };
  }

  async getDriverHistory(userId: string) {
    const rides = await this.rideRepo
      .createQueryBuilder('ride')
      .where('ride.driverId = :userId', { userId })
      .orderBy('ride.createdAt', 'DESC')
      .take(50)
      .getMany();

    const passengerIds = [...new Set(rides.map((r) => r.passengerId))];
    const passengers = passengerIds.length
      ? await this.userRepo.find({ where: { id: In(passengerIds) } })
      : [];
    const pMap = new Map(passengers.map((p) => [p.id, p.name]));

    const MONTHS = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];

    return rides.map((r) => {
      const d = r.createdAt;
      const date = `${d.getDate().toString().padStart(2, '0')} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
      const time = `${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`;
      return {
        id:            r.id,
        date,
        time,
        from:          r.originAddress      ?? `${Number(r.originLat).toFixed(3)}, ${Number(r.originLng).toFixed(3)}`,
        to:            r.destinationAddress ?? `${Number(r.destinationLat).toFixed(3)}, ${Number(r.destinationLng).toFixed(3)}`,
        status:        r.status,
        fare:          Number(r.fare ?? 0),
        distanceKm:    Number(r.distanceKm ?? 0),
        passengerName: pMap.get(r.passengerId) ?? null,
      };
    });
  }

  async getHotZones() {
    const hour = new Date().getHours();
    const zones = [
      { id: '1', name: 'Braga',     lat: -6.9175, lng: 107.6102, demand: 'high',   requestCount: hour >= 17 ? 9 : hour >= 7 ? 6 : 2 },
      { id: '2', name: 'Dago',      lat: -6.8857, lng: 107.6108, demand: 'medium', requestCount: hour >= 7  ? 4 : 1 },
      { id: '3', name: 'BIP',       lat: -6.9210, lng: 107.6072, demand: 'high',   requestCount: hour >= 8  ? 7 : 2 },
      { id: '4', name: 'Pasteur',   lat: -6.8972, lng: 107.5778, demand: 'low',    requestCount: 2 },
      { id: '5', name: 'Buah Batu', lat: -6.9447, lng: 107.6425, demand: hour >= 16 ? 'high' : 'medium', requestCount: hour >= 16 ? 6 : 3 },
    ];
    return zones;
  }

  async getTodayDetailedStats(userId: string) {
    const driver = await this.findByUserId(userId);
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const allRides = await this.rideRepo.find({ where: { driverId: userId } });
    const todayRides = allRides.filter((r) => r.createdAt >= todayStart);
    const completedToday = todayRides.filter((r) => r.status === RideStatus.DONE);

    const earningsToday = completedToday.reduce((s, r) => s + Number(r.fare ?? 0), 0);
    const kmToday = completedToday.reduce((s, r) => s + Number(r.distanceKm ?? 0), 0);

    const allCompleted = allRides.filter((r) => r.status === RideStatus.DONE);
    const totalEarnings = allCompleted.reduce((s, r) => s + Number(r.fare ?? 0), 0);

    const todayTarget = 200000;
    return {
      todayTrips: completedToday.length,
      todayEarnings: Math.round(earningsToday),
      todayKm: Math.round(kmToday * 10) / 10,
      todayTarget,
      totalTrips: driver.totalRides,
      totalEarnings: Math.round(totalEarnings),
      rating: Number(driver.rating),
      bonusActive: earningsToday >= todayTarget,
      bonusAmount: earningsToday >= todayTarget ? 25000 : 0,
    };
  }

  async getActiveRide(userId: string) {
    const ride = await this.rideRepo.findOne({
      where: [
        { driverId: userId, status: RideStatus.ACCEPTED },
        { driverId: userId, status: RideStatus.PICKUP },
        { driverId: userId, status: RideStatus.ONGOING },
      ],
      order: { createdAt: 'DESC' },
    });
    if (!ride) return null;

    const passenger = await this.userRepo.findOne({ where: { id: ride.passengerId } });

    return {
      rideId:       ride.id,
      status:       ride.status,
      passengerId:  ride.passengerId,
      passengerName:  passenger?.name  ?? null,
      passengerPhone: passenger?.phone ?? null,
      originLat:    Number(ride.originLat),
      originLng:    Number(ride.originLng),
      destinationLat: Number(ride.destinationLat),
      destinationLng: Number(ride.destinationLng),
      originAddress:      ride.originAddress,
      destinationAddress: ride.destinationAddress,
    };
  }

  async upgradeToDriver(userId: string, vehiclePlate: string, vehicleType: string, ktpNumber?: string, motorSubtype?: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User tidak ditemukan');

    const existing = await this.driverRepo.findOne({ where: { userId } });
    if (existing) throw new ConflictException('Akun driver sudah ada untuk user ini');

    const resolvedType = vehicleType === 'MOTOR' && motorSubtype
      ? `MOTOR_${motorSubtype.toUpperCase()}`
      : (vehicleType ?? 'MOTOR');

    const driver = this.driverRepo.create({
      userId,
      vehiclePlate: vehiclePlate ?? '',
      vehicleType: resolvedType,
      ktpNumber: ktpNumber ?? null,
      registrationStatus: 'PENDING',
    });
    await this.driverRepo.save(driver);

    user.role = 'DRIVER' as any;
    await this.userRepo.save(user);

    return { message: 'Berhasil upgrade ke driver', driverId: driver.id };
  }

  private async findByUserId(userId: string): Promise<Driver> {
    const driver = await this.driverRepo.findOne({ where: { userId } });
    if (!driver) throw new NotFoundException('Profil driver tidak ditemukan');
    return driver;
  }
}
