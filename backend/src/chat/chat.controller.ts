import {
  Controller,
  Get,
  Param,
  UseGuards,
  Request,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ChatService } from './chat.service';

@ApiTags('Chat')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('chat')
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @ApiOperation({ summary: 'Ambil riwayat pesan perjalanan' })
  @Get(':rideId/messages')
  getMessages(@Param('rideId') rideId: string) {
    return this.chatService.getByRide(rideId);
  }

  @ApiOperation({ summary: 'Perjalanan aktif & info driver penumpang' })
  @Get('active/me')
  getActiveRide(@Request() req: { user: { sub: string } }) {
    return this.chatService.getActiveRideForPassenger(req.user.sub);
  }
}
