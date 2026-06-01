import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ChatService } from './chat.service';
import { SenderRole } from './entities/chat_message.entity';
import { FirebaseService } from '../firebase/firebase.service';
import { Ride } from '../booking/entities/ride.entity';
import { User } from '../users/entities/user.entity';
import { Driver } from '../drivers/entities/driver.entity';

@WebSocketGateway({ namespace: '/chat', cors: { origin: '*' } })
export class ChatGateway implements OnGatewayConnection {
  @WebSocketServer()
  server: Server;

  constructor(
    private readonly chatService: ChatService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly firebaseService: FirebaseService,
    @InjectRepository(Ride)   private readonly rideRepo: Repository<Ride>,
    @InjectRepository(User)   private readonly userRepo: Repository<User>,
    @InjectRepository(Driver) private readonly driverRepo: Repository<Driver>,
  ) {}

  handleConnection(client: Socket) {
    try {
      const token =
        (client.handshake.auth?.token as string) ||
        (client.handshake.headers?.authorization as string)?.replace(
          'Bearer ',
          '',
        );
      if (!token) {
        client.disconnect();
        return;
      }
      const payload = this.jwtService.verify(token, {
        secret: this.configService.get<string>('JWT_SECRET'),
      });
      client.data.userId = payload.sub;
      client.data.role = payload.role;
    } catch {
      client.disconnect();
    }
  }

  @SubscribeMessage('joinRoom')
  async handleJoinRoom(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { rideId: string },
  ) {
    await client.join(`ride:${data.rideId}`);
    const history = await this.chatService.getByRide(data.rideId);
    client.emit('chatHistory', history);
  }

  @SubscribeMessage('sendMessage')
  async handleSendMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: { rideId: string; message: string; senderRole: SenderRole },
  ) {
    const msg = await this.chatService.saveMessage({
      rideId: data.rideId,
      senderId: client.data.userId,
      senderRole: data.senderRole,
      message: data.message,
    });
    this.server.to(`ride:${data.rideId}`).emit('newMessage', msg);
    this._notifyChatRecipient(data.rideId, data.senderRole, data.message).catch(() => {});
  }

  private async _notifyChatRecipient(rideId: string, senderRole: SenderRole, message: string) {
    const ride = await this.rideRepo.findOne({ where: { id: rideId } });
    if (!ride) return;

    const preview = message.length > 60 ? message.slice(0, 60) + '…' : message;

    if (senderRole === SenderRole.DRIVER && ride.passengerId) {
      const user = await this.userRepo.findOne({
        where: { id: ride.passengerId },
        select: ['fcmToken'],
      });
      if (user?.fcmToken) {
        await this.firebaseService.sendNotification(
          user.fcmToken,
          'Pesan dari Driver 💬',
          preview,
          { rideId, type: 'CHAT_FROM_DRIVER' },
        );
      }
    } else if (senderRole === SenderRole.PASSENGER && ride.driverId) {
      const driver = await this.driverRepo.findOne({
        where: { userId: ride.driverId },
        select: ['fcmToken'],
      });
      if (driver?.fcmToken) {
        await this.firebaseService.sendNotification(
          driver.fcmToken,
          'Pesan dari Penumpang 💬',
          preview,
          { rideId, type: 'CHAT_FROM_PASSENGER' },
        );
      }
    }
  }

  @SubscribeMessage('markRead')
  async handleMarkRead(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { rideId: string },
  ) {
    await this.chatService.markRead(data.rideId, client.data.userId);
    this.server
      .to(`ride:${data.rideId}`)
      .emit('messagesRead', { readerId: client.data.userId });
  }

  @SubscribeMessage('typing')
  handleTyping(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: { rideId: string; isTyping: boolean },
  ) {
    client.to(`ride:${data.rideId}`).emit('userTyping', {
      userId: client.data.userId,
      isTyping: data.isTyping,
    });
  }
}
