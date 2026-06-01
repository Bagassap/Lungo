import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DriversService } from './drivers.service';
import { DriversController } from './drivers.controller';
import { Driver } from './entities/driver.entity';
import { User } from '../users/entities/user.entity';
import { Ride } from '../booking/entities/ride.entity';
import { TrackingModule } from '../tracking/tracking.module';
import { AdminNotification } from '../admin/entities/admin_notification.entity';

@Module({
  imports: [
    TypeOrmModule.forFeature([Driver, User, Ride, AdminNotification]),
    TrackingModule,
  ],
  providers: [DriversService],
  controllers: [DriversController],
  exports: [DriversService],
})
export class DriversModule {}
