import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity('weekly_reports')
export class WeeklyReport {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  driverId!: string;

  @Column()
  driverName!: string;

  @Column({ type: 'date' })
  weekStart!: Date;

  @Column({ type: 'date' })
  weekEnd!: Date;

  @Column({ type: 'int', default: 0 })
  totalRides!: number;

  @Column({ type: 'int', default: 0 })
  completedRides!: number;

  @Column({ type: 'int', default: 0 })
  cancelledRides!: number;

  @Column({ type: 'decimal', precision: 14, scale: 2, default: 0 })
  totalEarnings!: number;

  @Column({ type: 'decimal', precision: 3, scale: 2, nullable: true })
  avgRating!: number | null;

  @Column({ type: 'decimal', precision: 10, scale: 3, default: 0 })
  totalDistanceKm!: number;

  @Column({ type: 'jsonb', nullable: true })
  dailyBreakdown!: Record<string, { rides: number; earnings: number }> | null;

  @CreateDateColumn()
  createdAt!: Date;
}
