import { IsString, IsNotEmpty, IsOptional, IsIn } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class DemoLoginDto {
  @ApiProperty({ example: '08111111111' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiPropertyOptional({ example: 'PASSENGER', enum: ['PASSENGER', 'DRIVER', 'ADMIN'] })
  @IsOptional()
  @IsString()
  @IsIn(['PASSENGER', 'DRIVER', 'ADMIN'])
  role?: string;
}
