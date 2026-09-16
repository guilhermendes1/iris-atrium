import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../core/api.service';

export interface UserRow {
  username: string;
  enabled: boolean;
  fullName: string;
  comment: string;
  roles: string[];
  lastLogin: string;
  userType: string;
}

export interface RoleRow {
  name: string;
  description: string;
  resources: { resource: string; permission: string }[];
}

export interface ResourceRow {
  name: string;
  description: string;
  publicPermission: string;
  type: string;
}

@Injectable({ providedIn: 'root' })
export class PermissionsService {
  constructor(private api: ApiService) {}

  users(): Observable<UserRow[]> {
    return this.api.get<UserRow[]>('/users');
  }

  rolesList(): Observable<RoleRow[]> {
    return this.api.get<RoleRow[]>('/roles');
  }

  resources(): Observable<ResourceRow[]> {
    return this.api.get<ResourceRow[]>('/resources');
  }

  setUserRoles(username: string, roles: string[]): Observable<{ ok: boolean }> {
    return this.api.put<{ ok: boolean }>(`/users/${encodeURIComponent(username)}/roles`, { roles });
  }

  createUser(body: Record<string, unknown>): Observable<{ ok: boolean }> {
    return this.api.post<{ ok: boolean }>('/users', body);
  }

  setUserEnabled(username: string, enabled: boolean): Observable<{ ok: boolean }> {
    return this.api.put<{ ok: boolean }>(`/users/${encodeURIComponent(username)}/enabled`, { enabled });
  }
}