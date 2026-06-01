import { Body, Controller, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Request } from 'express';
import { BookingService } from './booking.service';
import { CreateRideDto } from './dto/create-ride.dto';
import { UpdateRideStatusDto } from './dto/update-ride-status.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';

@ApiTags('Booking')
@ApiBearerAuth()
@UseGuards(JwtGuard)
@Controller('booking')
export class BookingController {
  constructor(private readonly bookingService: BookingService) {}

  @Post('rides')
  @ApiOperation({ summary: 'Buat ride baru (passenger)' })
  createRide(
    @Req() req: Request & { user: { userId: string } },
    @Body() dto: CreateRideDto,
  ) {
    dto.passengerId = req.user.userId;
    return this.bookingService.createRide(dto);
  }

  @Post('rides/:id/accept')
  @ApiOperation({ summary: 'Driver menerima ride' })
  acceptRide(
    @Param('id') rideId: string,
    @Req() req: Request & { user: { userId: string } },
  ) {
    return this.bookingService.acceptRide(rideId, req.user.userId);
  }

  @Patch('rides/:id/status')
  @ApiOperation({ summary: 'Update status ride (state machine)' })
  updateStatus(
    @Param('id') rideId: string,
    @Body() dto: UpdateRideStatusDto,
    @Req() req: Request & { user: { userId: string } },
  ) {
    dto.rideId = rideId;
    if (!dto.driverId) dto.driverId = req.user.userId;
    return this.bookingService.updateStatus(dto);
  }

  @Post('rides/:id/complete')
  @ApiOperation({ summary: 'Selesaikan ride dan hitung tarif' })
  completeRide(@Param('id') rideId: string) {
    return this.bookingService.completeRide(rideId);
  }

  @Post('rides/:id/cancel')
  @ApiOperation({ summary: 'Batalkan ride' })
  cancelRide(@Param('id') rideId: string) {
    return this.bookingService.cancelRide(rideId);
  }

  @Get('rides/:id')
  @ApiOperation({ summary: 'Detail ride' })
  getRide(@Param('id') rideId: string) {
    return this.bookingService.getRide(rideId);
  }

  @Post('rides/:id/rate')
  @ApiOperation({ summary: 'Penumpang memberi rating driver (1-5)' })
  rateRide(
    @Param('id') rideId: string,
    @Body() body: { rating: number },
    @Req() req: Request & { user: { userId: string } },
  ) {
    return this.bookingService.rateRide(rideId, req.user.userId, body.rating);
  }
}
