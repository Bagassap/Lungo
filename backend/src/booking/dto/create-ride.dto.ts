import { IsString, IsNotEmpty, IsNumber, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';

export class CreateRideDto {
  @ApiPropertyOptional({ example: 'uuid-passenger-id' })
  @IsOptional()
  @IsString()
  passengerId: string;

  @ApiProperty({ example: -6.2088 })
  @IsNumber()
  @Type(() => Number)
  originLat: number;

  @ApiProperty({ example: 106.8456 })
  @IsNumber()
  @Type(() => Number)
  originLng: number;

  @ApiProperty({ example: -6.2300 })
  @IsNumber()
  @Type(() => Number)
  destinationLat: number;

  @ApiProperty({ example: 106.8200 })
  @IsNumber()
  @Type(() => Number)
  destinationLng: number;

  @ApiPropertyOptional({ example: 'Jl. Sukajadi No. 12, Bandung' })
  @IsOptional()
  @IsString()
  originAddress?: string;

  @ApiPropertyOptional({ example: 'Braga City Walk, Bandung' })
  @IsOptional()
  @IsString()
  destinationAddress?: string;
}
