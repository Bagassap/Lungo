import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity('admin_notifications')
export class AdminNotification {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  type!: string; // 'NEW_USER' | 'NEW_DRIVER_REGISTRATION' | 'DRIVER_PAYMENT'

  @Column()
  title!: string;

  @Column({ type: 'text' })
  body!: string;

  @Column({ nullable: true, type: 'text' })
  targetId!: string | null;

  @Column({ default: false })
  isRead!: boolean;

  @CreateDateColumn()
  createdAt!: Date;
}
