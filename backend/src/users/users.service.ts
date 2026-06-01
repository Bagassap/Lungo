import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { User, UserRole } from './entities/user.entity';
import { UserAddress } from './entities/user_address.entity';
import { UserNotification } from './entities/user_notification.entity';
import { Ride } from '../booking/entities/ride.entity';
import { Driver } from '../drivers/entities/driver.entity';
import { RideStatus } from '../booking/enums/ride-status.enum';
import { UpdateUserDto } from './dto/update-user.dto';
import { CreateAddressDto } from './dto/create-address.dto';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(UserAddress)
    private readonly addressRepo: Repository<UserAddress>,
    @InjectRepository(UserNotification)
    private readonly notifRepo: Repository<UserNotification>,
    @InjectRepository(Ride)
    private readonly rideRepo: Repository<Ride>,
    @InjectRepository(Driver)
    private readonly driverRepo: Repository<Driver>,
  ) {}

  async updateFcmToken(userId: string, token: string): Promise<void> {
    await this.userRepo.update(userId, { fcmToken: token });
    // If user is a driver, sync token to Driver entity as well
    const user = await this.userRepo.findOne({ where: { id: userId }, select: ['role'] });
    if (user?.role === UserRole.DRIVER) {
      await this.driverRepo.update({ userId }, { fcmToken: token });
    }
  }

  async findById(id: string): Promise<User> {
    const user = await this.userRepo.findOne({ where: { id } });
    if (!user) throw new NotFoundException('User tidak ditemukan');
    return user;
  }

  async findByPhone(phone: string): Promise<User | null> {
    return this.userRepo.findOne({ where: { phone } });
  }

  async updateProfile(id: string, dto: UpdateUserDto): Promise<User> {
    const user = await this.findById(id);
    Object.assign(user, dto);
    return this.userRepo.save(user);
  }

  async getAddresses(userId: string): Promise<UserAddress[]> {
    return this.addressRepo.find({
      where: { userId },
      order: { isPrimary: 'DESC', createdAt: 'DESC' },
    });
  }

  async addAddress(userId: string, dto: CreateAddressDto): Promise<UserAddress> {
    if (dto.isPrimary) {
      await this.addressRepo.update({ userId }, { isPrimary: false });
    }
    const address = this.addressRepo.create({ ...dto, userId });
    return this.addressRepo.save(address);
  }

  async deleteAddress(userId: string, addressId: string): Promise<void> {
    const addr = await this.addressRepo.findOne({
      where: { id: addressId, userId },
    });
    if (!addr) throw new NotFoundException('Alamat tidak ditemukan');
    await this.addressRepo.remove(addr);
  }

  async getNotifications(userId: string): Promise<UserNotification[]> {
    return this.notifRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: 50,
    });
  }

  async markNotificationsRead(userId: string): Promise<void> {
    await this.notifRepo.update({ userId, isRead: false }, { isRead: true });
  }

  async createNotification(
    userId: string,
    title: string,
    body: string,
    type = 'info',
  ): Promise<UserNotification> {
    const notif = this.notifRepo.create({ userId, title, body, type });
    return this.notifRepo.save(notif);
  }

  async markNotificationRead(id: string): Promise<void> {
    await this.notifRepo.update({ id }, { isRead: true });
  }

  async deleteNotification(id: string): Promise<void> {
    await this.notifRepo.delete({ id });
  }

  async getStats(userId: string): Promise<{
    totalTrips: number;
    totalKm: number;
    avgRating: number;
    totalSpent: number;
  }> {
    const rides = await this.rideRepo.find({ where: { passengerId: userId } });
    const completed = rides.filter((r) => r.status === RideStatus.DONE);
    const totalKm =
      Math.round(
        completed.reduce((s, r) => s + Number(r.distanceKm ?? 0), 0) * 10,
      ) / 10;
    const totalSpent = completed.reduce((s, r) => s + Number(r.fare ?? 0), 0);
    return { totalTrips: completed.length, totalKm, avgRating: 4.9, totalSpent };
  }

  async getPassengerHistory(userId: string): Promise<Ride[]> {
    return this.rideRepo.find({
      where: { passengerId: userId },
      order: { createdAt: 'DESC' },
    });
  }

  async getActivityStats(userId: string) {
    const rides = await this.rideRepo.find({ where: { passengerId: userId } });
    const completed = rides.filter((r) => r.status === RideStatus.DONE);
    const cancelled = rides.filter((r) => r.status === RideStatus.CANCELLED);
    return {
      totalRides: rides.length,
      completedRides: completed.length,
      cancelledRides: cancelled.length,
      totalSpent: completed.reduce((sum, r) => sum + Number(r.fare ?? 0), 0),
      totalDistanceKm:
        Math.round(
          completed.reduce((sum, r) => sum + Number(r.distanceKm ?? 0), 0) * 10,
        ) / 10,
    };
  }

  async getEnrichedHistory(userId: string) {
    const rides = await this.rideRepo.find({
      where: { passengerId: userId },
      order: { createdAt: 'DESC' },
    });
    const driverIds = [
      ...new Set(rides.filter((r) => r.driverId).map((r) => r.driverId!)),
    ];
    const drivers =
      driverIds.length > 0
        ? await this.driverRepo.find({ where: { userId: In(driverIds) } })
        : [];
    const userIds = drivers.map((d) => d.userId);
    const driverUsers =
      userIds.length > 0
        ? await this.userRepo.find({ where: { id: In(userIds) } })
        : [];
    const driverMap = new Map(drivers.map((d) => [d.userId, d]));
    const userMap   = new Map(driverUsers.map((u) => [u.id, u]));

    return rides.map((ride) => {
      const driver     = ride.driverId ? driverMap.get(ride.driverId) : null;
      const driverUser = driver ? userMap.get(driver.userId) : null;
      const d = ride.createdAt;
      return {
        id: ride.id,
        date: d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }),
        time: d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit', hour12: false }),
        from: ride.originAddress ??
          `${Number(ride.originLat).toFixed(3)}, ${Number(ride.originLng).toFixed(3)}`,
        to: ride.destinationAddress ??
          `${Number(ride.destinationLat).toFixed(3)}, ${Number(ride.destinationLng).toFixed(3)}`,
        status: ride.status,
        fare: Number(ride.fare ?? 0),
        distanceKm: Number(ride.distanceKm ?? 0),
        driverName: driverUser?.name ?? null,
        vehiclePlate: driver?.vehiclePlate ?? null,
        vehicleType: driver?.vehicleType ?? null,
        driverRating: driver ? Number(driver.rating) : null,
        passengerRating: ride.passengerRating ?? null,
      };
    });
  }

  async getLastDestinations(userId: string, lat: number, lng: number) {
    const rides = await this.rideRepo.find({
      where: { passengerId: userId, status: RideStatus.DONE },
      order: { createdAt: 'DESC' },
      take: 3,
    });
    const labels = ['Tujuan Terakhir', 'Perjalanan Sebelumnya', 'Perjalanan Lama'];
    return rides.map((ride, i) => ({
      id: ride.id,
      name: ride.destinationAddress ?? labels[i] ?? 'Tujuan Lama',
      destinationLat: Number(ride.destinationLat),
      destinationLng: Number(ride.destinationLng),
      distanceKm:
        Math.round(
          this._haversine(lat, lng, Number(ride.destinationLat), Number(ride.destinationLng)) * 10,
        ) / 10,
    }));
  }

  async getLocationSuggestions(lat: number, lng: number): Promise<{ displayName: string }> {
    if (!lat || !lng) return { displayName: 'Lokasi Anda' };
    try {
      const url = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json`;
      const res  = await fetch(url, {
        headers: { 'User-Agent': 'Lungo-App/1.0 (citatonuget@gmail.com)' },
      });
      const data = await res.json() as any;
      const addr = data?.address ?? {};
      const parts = [
        addr.road,
        addr.suburb ?? addr.neighbourhood,
        addr.city ?? addr.town ?? addr.village ?? addr.county,
      ].filter(Boolean);
      const displayName = parts.length > 0 ? parts.join(', ') : (data?.display_name?.split(',')[0] ?? 'Lokasi Anda');
      return { displayName };
    } catch {
      return { displayName: 'Lokasi Anda' };
    }
  }

  private _haversine(lat1: number, lon1: number, lat2: number, lon2: number): number {
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
