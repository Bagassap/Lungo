import { IsString, IsNotEmpty, IsIn, IsOptional } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class SelectRoleDto {
  @ApiProperty({ example: '085640168132' })
  @IsString()
  @IsNotEmpty()
  phone: string;

  @ApiProperty({ example: 'PASSENGER', enum: ['PASSENGER', 'DRIVER', 'ADMIN'] })
  @IsString()
  @IsIn(['PASSENGER', 'DRIVER', 'ADMIN'])
  role: string;

  @ApiPropertyOptional({ description: 'Temp token dari response verifyOtp multi-role. Opsional jika sudah login.' })
  @IsOptional()
  @IsString()
  tempToken?: string;
}
