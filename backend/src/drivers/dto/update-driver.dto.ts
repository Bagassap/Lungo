import { IsString, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateDriverDto {
  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  fcmToken?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  ktpPhotoUrl?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  simPhotoUrl?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  vehiclePlate?: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  vehicleType?: string;
}
