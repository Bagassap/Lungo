import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { ChatMessage, SenderRole } from './entities/chat_message.entity';
import { Ride } from '../booking/entities/ride.entity';
import { RideStatus } from '../booking/enums/ride-status.enum';
import { Driver } from '../drivers/entities/driver.entity';
import { User } from '../users/entities/user.entity';

const ACTIVE_STATUSES: RideStatus[] = [
  RideStatus.SEARCHING,
  RideStatus.ACCEPTED,
  RideStatus.PICKUP,
  RideStatus.ONGOING,
];

@Injectable()
export class ChatService {
  constructor(
    @InjectRepository(ChatMessage)
    private readonly repo: Repository<ChatMessage>,
    @InjectRepository(Ride)
    private readonly rideRepo: Repository<Ride>,
    @InjectRepository(Driver)
    private readonly driverRepo: Repository<Driver>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  async saveMessage(dto: {
    rideId: string;
    senderId: string;
    senderRole: SenderRole;
    message: string;
  }): Promise<ChatMessage> {
    const msg = this.repo.create(dto);
    return this.repo.save(msg);
  }

  async getByRide(rideId: string): Promise<ChatMessage[]> {
    return this.repo.find({
      where: { rideId },
      order: { createdAt: 'ASC' },
    });
  }

  async markRead(rideId: string, _readerId: string): Promise<void> {
    await this.repo.update({ rideId, isRead: false }, { isRead: true });
  }

  async getAllActive(): Promise<{ rideId: string; count: number }[]> {
    return this.repo
      .createQueryBuilder('m')
      .select('m.rideId', 'rideId')
      .addSelect('COUNT(*)', 'count')
      .groupBy('m.rideId')
      .getRawMany();
  }

  async getActiveRideForPassenger(passengerId: string): Promise<{
    rideId: string;
    status: string;
    driver: {
      userId: string;
      name: string;
      vehiclePlate: string;
      vehicleType: string;
      rating: number;
      isOnline: boolean;
    } | null;
  }> {
    const ride = await this.rideRepo.findOne({
      where: {
        passengerId,
        status: In(ACTIVE_STATUSES),
      },
      order: { createdAt: 'DESC' },
    });

    if (!ride) {
      throw new NotFoundException('Tidak ada perjalanan aktif');
    }

    let driverInfo: {
      userId: string;
      name: string;
      vehiclePlate: string;
      vehicleType: string;
      rating: number;
      isOnline: boolean;
    } | null = null;
    if (ride.driverId) {
      const driver = await this.driverRepo.findOne({
        where: { userId: ride.driverId },
      });
      const user = await this.userRepo.findOne({
        where: { id: ride.driverId },
      });
      if (driver && user) {
        driverInfo = {
          userId: driver.userId,
          name: user.name ?? '',
          vehiclePlate: driver.vehiclePlate,
          vehicleType: driver.vehicleType,
          rating: Number(driver.rating),
          isOnline: driver.isOnline,
        };
      }
    }

    return { rideId: ride.id, status: ride.status, driver: driverInfo };
  }
}
