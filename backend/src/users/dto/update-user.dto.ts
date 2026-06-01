import { IsString, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class UpdateUserDto {
  @ApiProperty({ required: false, example: 'Budi Santoso' })
  @IsString()
  @IsOptional()
  name?: string;
}
