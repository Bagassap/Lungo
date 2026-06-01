import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Unique,
} from 'typeorm';

export enum UserRole {
  PASSENGER = 'PASSENGER',
  DRIVER = 'DRIVER',
  ADMIN = 'ADMIN',
}

@Entity('users')
@Unique('UQ_users_phone_role', ['phone', 'role'])
export class User {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  phone!: string;

  @Column({ type: 'varchar', nullable: true })
  name!: string | null;

  @Column({ type: 'enum', enum: UserRole, nullable: true })
  role!: UserRole | null;

  @Column({ default: false })
  isVerified!: boolean;

  @Column({ nullable: true, type: 'text' })
  refreshToken!: string | null;

  @Column({ nullable: true, type: 'text' })
  fcmToken!: string | null;

  @Column({ type: 'decimal', precision: 14, scale: 2, default: 0 })
  balance!: number;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
