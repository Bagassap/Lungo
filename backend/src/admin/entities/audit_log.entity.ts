import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity('audit_logs')
export class AuditLog {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  adminId!: string;

  @Column()
  adminName!: string;

  @Column()
  action!: string;

  @Column({ nullable: true, type: 'text' })
  details!: string | null;

  @Column({ nullable: true, type: 'varchar' })
  targetId!: string | null;

  @Column({ nullable: true, type: 'varchar' })
  targetType!: string | null;

  @Column({ nullable: true, type: 'varchar' })
  ipAddress!: string | null;

  @CreateDateColumn()
  createdAt!: Date;
}
