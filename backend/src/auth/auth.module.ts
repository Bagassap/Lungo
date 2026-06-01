import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { User } from '../users/entities/user.entity';
import { Driver } from '../drivers/entities/driver.entity';
import { AdminNotification } from '../admin/entities/admin_notification.entity';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { JwtStrategy } from './strategies/jwt.strategy';
import { JwtGuard } from './guards/jwt.guard';
import { ZenzivaService } from './zenziva.service';

@Module({
  imports: [
    PassportModule,
    TypeOrmModule.forFeature([User, Driver, AdminNotification]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>('JWT_SECRET'),
        signOptions: { expiresIn: config.get('JWT_EXPIRES_IN') as any },
      }),
    }),
  ],
  providers: [AuthService, ZenzivaService, JwtAuthGuard, JwtStrategy, JwtGuard],
  controllers: [AuthController],
  exports: [AuthService, ZenzivaService, JwtAuthGuard, JwtGuard, JwtModule],
})
export class AuthModule {}
