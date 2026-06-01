import { IsString, IsNotEmpty, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class DriverSubmitRegistrationDto {
  @ApiProperty({ example: 'Bandung' })
  @IsString()
  @IsNotEmpty()
  birthPlace: string;

  @ApiProperty({ example: '1995-08-17' })
  @IsString()
  @IsNotEmpty()
  birthDate: string;

  @ApiProperty({ example: 'Jl. Merdeka No. 10, Bandung' })
  @IsString()
  @IsNotEmpty()
  address: string;

  @ApiProperty({ example: 'MOTOR' })
  @IsString()
  @IsOptional()
  vehicleType?: string;

  @ApiProperty({ example: 'D 1234 XYZ' })
  @IsString()
  @IsOptional()
  vehiclePlate?: string;
}
