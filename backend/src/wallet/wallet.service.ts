import {
  Injectable,
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { User } from '../users/entities/user.entity';
import { WalletTransaction, TxType } from './entities/wallet_transaction.entity';

@Injectable()
export class WalletService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(WalletTransaction)
    private readonly txRepo: Repository<WalletTransaction>,
    private readonly dataSource: DataSource,
  ) {}

  async getBalance(userId: string): Promise<{ balance: number }> {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User tidak ditemukan');
    return { balance: Math.round(Number(user.balance)) };
  }

  async credit(
    userId: string,
    amount: number,
    description: string,
    rideId?: string,
  ): Promise<WalletTransaction> {
    return this.dataSource.transaction(async (em) => {
      const user = await em.findOne(User, {
        where: { id: userId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!user) throw new NotFoundException('User tidak ditemukan');

      const newBalance = Number(user.balance) + amount;
      user.balance = newBalance;
      await em.save(User, user);

      const tx = em.create(WalletTransaction, {
        userId,
        type:         TxType.CREDIT,
        amount,
        balanceAfter: newBalance,
        description,
        rideId:       rideId ?? null,
      });
      return em.save(WalletTransaction, tx);
    });
  }

  async debit(
    userId: string,
    amount: number,
    description: string,
    rideId?: string,
  ): Promise<WalletTransaction> {
    return this.dataSource.transaction(async (em) => {
      const user = await em.findOne(User, {
        where: { id: userId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!user) throw new NotFoundException('User tidak ditemukan');

      const current = Number(user.balance);
      if (current < amount) {
        throw new BadRequestException('Saldo tidak mencukupi');
      }

      const newBalance = current - amount;
      user.balance = newBalance;
      await em.save(User, user);

      const tx = em.create(WalletTransaction, {
        userId,
        type:         TxType.DEBIT,
        amount,
        balanceAfter: newBalance,
        description,
        rideId:       rideId ?? null,
      });
      return em.save(WalletTransaction, tx);
    });
  }

  async topUp(userId: string, amount: number): Promise<{ balance: number }> {
    if (amount <= 0) throw new BadRequestException('Nominal tidak valid');
    await this.credit(userId, amount, `Top-up saldo Rp ${amount.toLocaleString('id-ID')}`);
    return this.getBalance(userId);
  }

  async withdraw(userId: string, amount: number): Promise<{ balance: number }> {
    if (amount <= 0) throw new BadRequestException('Nominal tidak valid');
    await this.debit(userId, amount, `Tarik saldo Rp ${amount.toLocaleString('id-ID')}`);
    return this.getBalance(userId);
  }

  async getTransactions(userId: string, limit = 20): Promise<WalletTransaction[]> {
    return this.txRepo.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }
}
