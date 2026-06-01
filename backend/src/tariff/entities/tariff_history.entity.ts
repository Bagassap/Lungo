import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity('tariff_history')
export class TariffHistory {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'text' })
  change: string;

  @Column({ nullable: true, type: 'text' })
  adminId: string | null;

  @Column({ nullable: true, type: 'text' })
  adminName: string | null;

  @CreateDateColumn()
  createdAt: Date;
}
