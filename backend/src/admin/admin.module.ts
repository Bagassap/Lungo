import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { ScheduleModule } from '@nestjs/schedule';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AdminService } from './admin.service';
import { AdminController, ComplaintController } from './admin.controller';
import { User } from '../users/entities/user.entity';
import { Ride } from '../booking/entities/ride.entity';
import { Driver } from '../drivers/entities/driver.entity';
import { Complaint } from './entities/complaint.entity';
import { WeeklyReport } from './entities/weekly_report.entity';
import { AuditLog } from './entities/audit_log.entity';
import { AdminNotification } from './entities/admin_notification.entity';
import { TariffModule } from '../tariff/tariff.module';
import { ChatMessage } from '../chat/entities/chat_message.entity';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    TypeOrmModule.forFeature([User, Ride, Driver, Complaint, WeeklyReport, AuditLog, AdminNotification, ChatMessage]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        secret: cfg.get<string>('JWT_SECRET'),
      }),
    }),
    TariffModule,
  ],
  providers: [AdminService],
  controllers: [AdminController, ComplaintController],
  exports: [AdminService],
})
export class AdminModule {}
