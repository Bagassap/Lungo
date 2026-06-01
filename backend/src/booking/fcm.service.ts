import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Driver } from '../drivers/entities/driver.entity';
import { User } from '../users/entities/user.entity';
import { FirebaseService } from '../firebase/firebase.service';

@Injectable()
export class FcmService {
  private readonly logger = new Logger(FcmService.name);

  constructor(
    private readonly firebase: FirebaseService,
    @InjectRepository(Driver)
    private readonly driverRepo: Repository<Driver>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  async sendNotification(
    fcmToken: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    await this.firebase.sendNotification(fcmToken, title, body, data);
  }

  async notifyPassenger(
    passengerId: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    const user = await this.userRepo.findOne({
      where: { id: passengerId },
      select: ['fcmToken'],
    });
    if (!user?.fcmToken) return;
    try {
      await this.firebase.sendNotification(user.fcmToken, title, body, data);
      this.logger.log(`FCM dikirim ke penumpang ${passengerId}: ${title}`);
    } catch (err) {
      this.logger.warn(`Gagal kirim FCM ke penumpang ${passengerId}: ${err}`);
    }
  }

  async notifyDriver(
    driverUserId: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    const driver = await this.driverRepo.findOne({
      where: { userId: driverUserId },
      select: ['fcmToken'],
    });
    if (!driver?.fcmToken) return;
    try {
      await this.firebase.sendNotification(driver.fcmToken, title, body, data);
      this.logger.log(`FCM dikirim ke driver ${driverUserId}: ${title}`);
    } catch (err) {
      this.logger.warn(`Gagal kirim FCM ke driver ${driverUserId}: ${err}`);
    }
  }

  async notifyAllByRole(
    role: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    const roles = role === 'ALL' ? ['PASSENGER', 'DRIVER'] : [role];
    const users = await this.userRepo
      .createQueryBuilder('u')
      .select('u.fcmToken')
      .where('u.role IN (:...roles)', { roles })
      .andWhere('u.fcmToken IS NOT NULL')
      .getMany();

    const tokens = users.map((u) => u.fcmToken).filter(Boolean) as string[];
    if (!tokens.length) {
      this.logger.warn(`Tidak ada FCM token untuk role ${role}`);
      return;
    }

    const CHUNK = 500;
    for (let i = 0; i < tokens.length; i += CHUNK) {
      await this.firebase.sendMulticast(tokens.slice(i, i + CHUNK), title, body, data);
    }
    this.logger.log(`Broadcast FCM ke ${tokens.length} user (${role}): ${title}`);
  }

  async notifyNearbyDrivers(
    driverIds: string[],
    rideData: Record<string, unknown>,
  ): Promise<void> {
    if (!driverIds.length) return;

    const drivers = await this.driverRepo
      .createQueryBuilder('d')
      .select('d.fcmToken')
      .where('d.userId IN (:...ids)', { ids: driverIds })
      .andWhere('d.fcmToken IS NOT NULL')
      .getMany();

    const tokens = drivers.map((d) => d.fcmToken as string);
    if (!tokens.length) {
      this.logger.warn(
        `Tidak ada FCM token untuk ${driverIds.length} driver, notifikasi dilewati`,
      );
      return;
    }

    const data: Record<string, string> = {
      type: 'NEW_RIDE_REQUEST',
      rideId: String(rideData['rideId'] ?? ''),
      originLat: String(rideData['originLat'] ?? ''),
      originLng: String(rideData['originLng'] ?? ''),
      originAddress: String(rideData['originAddress'] ?? ''),
      destinationLat: String(rideData['destinationLat'] ?? ''),
      destinationLng: String(rideData['destinationLng'] ?? ''),
      destinationAddress: String(rideData['destinationAddress'] ?? ''),
      distanceKm: String(rideData['distanceKm'] ?? '0'),
      estimatedFare: String(rideData['estimatedFare'] ?? '0'),
      passengerName: String(rideData['passengerName'] || 'Penumpang'),
      passengerRating: String(rideData['passengerRating'] ?? '5'),
    };

    await this.firebase.sendMulticast(
      tokens,
      'Permintaan Ojek Baru',
      'Ada penumpang yang membutuhkan ojek di dekat Anda!',
      data,
    );

    this.logger.log(
      `FCM dikirim ke ${tokens.length} driver untuk ride ${rideData['rideId']}`,
    );
  }
}
