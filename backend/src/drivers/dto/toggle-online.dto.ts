import { IsBoolean, IsNumber, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';

export class ToggleOnlineDto {
  @ApiProperty({ example: true })
  @IsBoolean()
  @IsNotEmpty()
  isOnline: boolean;

  @ApiProperty({ example: -6.2088 })
  @IsNumber()
  @Type(() => Number)
  latitude: number;

  @ApiProperty({ example: 106.8456 })
  @IsNumber()
  @Type(() => Number)
  longitude: number;
}
