import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../core/api.service';

export interface Credential {
  type: string;
  alias: string;
  description: string;
  status: string;
  enabled: boolean;
  issuer: string;
  subject: string;
  validFrom: string;
  validTo: string;
  extra?: Record<string, unknown>;
}

@Injectable({ providedIn: 'root' })
export class SecurityService {
  constructor(private api: ApiService) {}

  credentials(type?: string): Observable<Credential[]> {
    const path = type && type !== 'all' ? `/security/credentials/${encodeURIComponent(type)}` : '/security/credentials';
    return this.api.get<Credential[]>(path);
  }

  detail(type: string, alias: string): Observable<Credential> {
    return this.api.get<Credential>(`/security/credentials/${encodeURIComponent(type)}/${encodeURIComponent(alias)}`);
  }
}