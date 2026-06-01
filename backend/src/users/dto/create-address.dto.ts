import { IsString, IsOptional, IsNumber, IsBoolean } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateAddressDto {
  @ApiProperty({ example: 'Rumah' })
  @IsString()
  label: string;

  @ApiProperty({ example: 'Jl. Melati No. 12, Jakarta Selatan' })
  @IsString()
  detail: string;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  lat?: number;

  @ApiProperty({ required: false })
  @IsNumber()
  @IsOptional()
  lng?: number;

  @ApiProperty({ required: false, default: false })
  @IsBoolean()
  @IsOptional()
  isPrimary?: boolean;
}
