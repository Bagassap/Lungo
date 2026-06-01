import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('drivers')
export class Driver {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  userId!: string;

  @Column({ nullable: true, type: 'text' })
  fcmToken!: string | null;

  @Column({ nullable: true, type: 'text' })
  ktpPhotoUrl!: string | null;

  @Column({ nullable: true, type: 'text' })
  simPhotoUrl!: string | null;

  @Column({ nullable: true, type: 'text' })
  bpkbPhotoUrl!: string | null;

  @Column({ nullable: true, type: 'text' })
  stnkPhotoUrl!: string | null;

  @Column({ nullable: true, type: 'text' })
  birthPlace!: string | null;

  @Column({ nullable: true, type: 'date' })
  birthDate!: Date | null;

  @Column({ nullable: true, type: 'text' })
  address!: string | null;

  @Column({ default: 'PENDING' })
  registrationStatus!: string;

  @Column({ nullable: true, type: 'text' })
  ktpNumber!: string | null;

  @Column({ nullable: true })
  vehiclePlate!: string;

  @Column()
  vehicleType!: string;

  @Column({ default: false })
  isOnline!: boolean;

  @Column({ default: 0 })
  totalRides!: number;

  @Column({ type: 'decimal', precision: 3, scale: 2, default: 5.0 })
  rating!: number;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
