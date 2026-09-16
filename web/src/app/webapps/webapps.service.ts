import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../core/api.service';

export interface WebApp {
  path: string;
  name: string;
  namespace: string;
  enabled: boolean;
  type: string;
  authentication: string;
  dispatchClass: string;
  physicalPath: string;
  serving: boolean;
  resources: { resource: string; permission: string }[];
}

export interface InstalledApp {
  name: string;
  namespace: string;
  dispatchClass: string;
  resource: string;
  enabled: boolean;
  swaggerSpecURL: string;
}

export interface InstalledAppsResponse {
  ok: boolean;
  apps: InstalledApp[];
  raw: string;
}

@Injectable({ providedIn: 'root' })
export class WebappsService {
  constructor(private api: ApiService) {}

  list(): Observable<WebApp[]> {
    return this.api.get<WebApp[]>('/webapps');
  }

  installed(namespace?: string): Observable<InstalledAppsResponse> {
    return this.api.get<InstalledAppsResponse>('/webapps/installed', namespace ? { ns: namespace } : undefined);
  }

  spec(namespace: string, app: string): Observable<string> {
    return this.api.raw('/webapps/spec', { ns: namespace, app });
  }

  create(name: string, props: Record<string, unknown>): Observable<{ ok: boolean }> {
    return this.api.post<{ ok: boolean }>('/webapps', { name, ...props });
  }

  modify(name: string, props: Record<string, unknown>): Observable<{ ok: boolean }> {
    return this.api.put<{ ok: boolean }>('/webapps', { name, ...props });
  }

  remove(name: string): Observable<{ ok: boolean }> {
    return this.api.delete<{ ok: boolean }>('/webapps', { name });
  }
}