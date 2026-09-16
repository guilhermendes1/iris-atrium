import { Injectable } from '@angular/core';
import { HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { ApiService } from './api.service';

export function toBase64(value: string): string {
  return btoa(unescape(encodeURIComponent(value)));
}

@Injectable({ providedIn: 'root' })
export class SessionService {
  private readonly tokenKey = 'mp.credentials';
  private readonly userKey = 'mp.username';

  constructor(private api: ApiService) {}

  login(username: string, password: string): Observable<{ ok: boolean; username: string }> {
    const headers = new HttpHeaders({ Authorization: `Basic ${toBase64(`${username}:${password}`)}` });
    return this.api.post<{ ok: boolean; username: string }>('/login', { username, password }, headers).pipe(
      tap(() => {
        localStorage.setItem(this.tokenKey, toBase64(`${username}:${password}`));
        localStorage.setItem(this.userKey, username);
      }),
    );
  }

  logout(): void {
    this.api.post('/logout', {}).subscribe({ error: () => undefined });
    localStorage.removeItem(this.tokenKey);
    localStorage.removeItem(this.userKey);
  }

  get token(): string | null {
    return localStorage.getItem(this.tokenKey);
  }

  get username(): string {
    return localStorage.getItem(this.userKey) ?? '';
  }

  isAuthenticated(): boolean {
    return !!this.token;
  }
}