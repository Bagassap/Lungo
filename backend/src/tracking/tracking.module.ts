import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TrackingService } from './tracking.service';
import { TrackingController } from './tracking.controller';
import { TrackingGateway } from './tracking.gateway';
import { RedisService } from './redis.service';
import { Location } from './entities/location.entity';
import { UserNotification } from '../users/entities/user_notification.entity';
import { Ride } from '../booking/entities/ride.entity';
import { User } from '../users/entities/user.entity';
import { TariffModule } from '../tariff/tariff.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [TypeOrmModule.forFeature([Location, UserNotification, Ride, User]), TariffModule, AuthModule],
  providers: [TrackingService, TrackingGateway, RedisService],
  controllers: [TrackingController],
  exports: [TrackingService, RedisService, TrackingGateway],
})
export class TrackingModule {}
