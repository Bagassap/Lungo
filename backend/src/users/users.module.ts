import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { User } from './entities/user.entity';
import { UserAddress } from './entities/user_address.entity';
import { UserNotification } from './entities/user_notification.entity';
import { Ride } from '../booking/entities/ride.entity';
import { Driver } from '../drivers/entities/driver.entity';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([User, UserAddress, UserNotification, Ride, Driver]),
    AuthModule,
  ],
  providers: [UsersService],
  controllers: [UsersController],
  exports: [UsersService],
})
export class UsersModule {}
