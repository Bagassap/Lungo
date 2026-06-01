import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

export enum ComplaintType {
  COMPLAINT  = 'COMPLAINT',
  SUGGESTION = 'SUGGESTION',
  PRAISE     = 'PRAISE',
}

export enum ComplaintStatus {
  OPEN      = 'OPEN',
  IN_REVIEW = 'IN_REVIEW',
  RESOLVED  = 'RESOLVED',
  CLOSED    = 'CLOSED',
}

@Entity('complaints')
export class Complaint {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  passengerId!: string;

  @Column({ nullable: true, type: 'varchar' })
  driverId!: string | null;

  @Column({ nullable: true, type: 'varchar' })
  rideId!: string | null;

  @Column({ type: 'enum', enum: ComplaintType, default: ComplaintType.COMPLAINT })
  type!: ComplaintType;

  @Column({ type: 'varchar', length: 200 })
  subject!: string;

  @Column({ type: 'text' })
  message!: string;

  @Column({ type: 'enum', enum: ComplaintStatus, default: ComplaintStatus.OPEN })
  status!: ComplaintStatus;

  @Column({ nullable: true, type: 'text' })
  adminReply!: string | null;

  @Column({ nullable: true, type: 'varchar' })
  repliedBy!: string | null;

  @Column({ nullable: true, type: 'timestamp' })
  repliedAt!: Date | null;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
