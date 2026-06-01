import { IsString, IsEnum, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { RideStatus } from '../enums/ride-status.enum';

export class UpdateRideStatusDto {
  @IsString()
  @IsOptional()
  rideId?: string;

  @ApiProperty({ enum: RideStatus })
  @IsEnum(RideStatus)
  status: RideStatus;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  driverId?: string;
}
