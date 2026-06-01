import { Controller, Get, Query, ParseFloatPipe, DefaultValuePipe, UseGuards } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiQuery, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TrackingService } from './tracking.service';

@ApiTags('Tracking')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('tracking')
export class TrackingController {
  constructor(private readonly trackingService: TrackingService) {}

  @Get('drivers/count')
  @ApiOperation({ summary: 'Jumlah driver aktif dalam radius' })
  @ApiQuery({ name: 'lat', type: Number, example: -6.9175 })
  @ApiQuery({ name: 'lng', type: Number, example: 107.6191 })
  @ApiQuery({ name: 'radius', type: Number, required: false, example: 3 })
  getDriverCount(
    @Query('lat', ParseFloatPipe) lat: number,
    @Query('lng', ParseFloatPipe) lng: number,
    @Query('radius', new DefaultValuePipe(3), ParseFloatPipe) radius: number,
  ) {
    return this.trackingService.getDriverCount(lat, lng, radius);
  }

  @Get('drivers/nearby')
  @ApiOperation({ summary: 'Ambil driver terdekat dalam radius (maks 3)' })
  @ApiQuery({ name: 'lat', type: Number, example: -6.2088 })
  @ApiQuery({ name: 'lng', type: Number, example: 106.8456 })
  @ApiQuery({ name: 'radius', type: Number, required: false, example: 5 })
  getNearbyDrivers(
    @Query('lat', ParseFloatPipe) lat: number,
    @Query('lng', ParseFloatPipe) lng: number,
    @Query('radius', new DefaultValuePipe(5), ParseFloatPipe) radius: number,
  ) {
    return this.trackingService.getNearbyDrivers(lat, lng, radius);
  }
}
