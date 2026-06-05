import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';
import { RideStatus } from '../enums/ride-status.enum';

@Entity('rides')
export class Ride {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  passengerId!: string;

  @Column({ nullable: true, type: 'varchar' })
  driverId!: string | null;

  @Column({ type: 'decimal', precision: 10, scale: 7 })
  originLat!: number;

  @Column({ type: 'decimal', precision: 10, scale: 7 })
  originLng!: number;

  @Column({ type: 'decimal', precision: 10, scale: 7 })
  destinationLat!: number;

  @Column({ type: 'decimal', precision: 10, scale: 7 })
  destinationLng!: number;

  @Column({ nullable: true, type: 'text' })
  originAddress!: string | null;

  @Column({ nullable: true, type: 'text' })
  destinationAddress!: string | null;

  @Column({ type: 'enum', enum: RideStatus, default: RideStatus.SEARCHING })
  status!: RideStatus;

  @Column({ type: 'decimal', precision: 12, scale: 2, nullable: true })
  fare!: number | null;

  @Column({ type: 'decimal', precision: 8, scale: 3, nullable: true })
  distanceKm!: number | null;

  @Column({ type: 'int', nullable: true })
  passengerRating!: number | null;

  @Column({ nullable: true, type: 'varchar' })
  zona!: string | null;

  @Column({ type: 'decimal', precision: 12, scale: 2, nullable: true })
  fareDriver!: number | null;

  @Column({ type: 'decimal', precision: 12, scale: 2, nullable: true })
  farePassenger!: number | null;

  @Column({ type: 'int', nullable: true })
  feeLungo!: number | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
