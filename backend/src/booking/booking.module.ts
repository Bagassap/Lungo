import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { BookingService } from './booking.service';
import { BookingController } from './booking.controller';
import { FcmService } from './fcm.service';
import { Ride } from './entities/ride.entity';
import { User } from '../users/entities/user.entity';
import { Driver } from '../drivers/entities/driver.entity';
import { UserNotification } from '../users/entities/user_notification.entity';
import { TrackingModule } from '../tracking/tracking.module';
import { TariffModule } from '../tariff/tariff.module';
import { WalletModule } from '../wallet/wallet.module';

@Module({
  imports: [TypeOrmModule.forFeature([Ride, User, Driver, UserNotification]), TrackingModule, TariffModule, WalletModule],
  providers: [BookingService, FcmService],
  controllers: [BookingController],
  exports: [BookingService],
})
export class BookingModule {}
