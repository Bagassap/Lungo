import { IsString, IsNotEmpty } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class LoginDto {
  @ApiProperty({ example: '08123456789' })
  @IsString()
  @IsNotEmpty()
  phone: string;
}
