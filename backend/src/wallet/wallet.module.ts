import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { WalletService } from './wallet.service';
import { WalletController } from './wallet.controller';
import { WalletTransaction } from './entities/wallet_transaction.entity';
import { User } from '../users/entities/user.entity';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([WalletTransaction, User]),
    AuthModule,
  ],
  controllers: [WalletController],
  providers:   [WalletService],
  exports:     [WalletService],
})
export class WalletModule {}
