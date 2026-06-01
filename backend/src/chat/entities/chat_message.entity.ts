import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

export enum SenderRole {
  PASSENGER = 'PASSENGER',
  DRIVER = 'DRIVER',
}

@Entity('chat_messages')
export class ChatMessage {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  rideId!: string;

  @Column()
  senderId!: string;

  @Column({ type: 'enum', enum: SenderRole })
  senderRole!: SenderRole;

  @Column({ type: 'text' })
  message!: string;

  @Column({ default: false })
  isRead!: boolean;

  @CreateDateColumn()
  createdAt!: Date;
}
