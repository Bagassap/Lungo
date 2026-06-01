import {
  Entity,
  PrimaryColumn,
  Column,
  UpdateDateColumn,
} from 'typeorm';

@Entity('tariff_config')
export class TariffConfig {
  @PrimaryColumn({ type: 'int', default: 1 })
  id: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 14000 })
  basePrice: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 2100 })
  pricePerKm: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 500 })
  pricePerMinute: number;

  @Column({ type: 'decimal', precision: 12, scale: 2, default: 14000 })
  minimumFare: number;

  @Column({ nullable: true, type: 'text' })
  updatedBy: string | null;

  @UpdateDateColumn()
  updatedAt: Date;
}
