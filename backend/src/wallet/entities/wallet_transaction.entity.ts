import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

export enum TxType {
  CREDIT = 'CREDIT',
  DEBIT  = 'DEBIT',
}

@Entity('wallet_transactions')
export class WalletTransaction {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  userId!: string;

  @Column({ type: 'enum', enum: TxType })
  type!: TxType;

  @Column({ type: 'decimal', precision: 14, scale: 2 })
  amount!: number;

  @Column({ type: 'decimal', precision: 14, scale: 2 })
  balanceAfter!: number;

  @Column({ type: 'text', nullable: true })
  description!: string | null;

  @Column({ type: 'varchar', nullable: true })
  rideId!: string | null;

  @CreateDateColumn()
  createdAt!: Date;
}
