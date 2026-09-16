import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../core/api.service';

export interface Metrics {
  cpuPercent: number;
  memoryTotalKB: number;
  memoryUsedKB: number;
  memoryPercent: number;
  uptimeSeconds: number;
}

export interface Disk {
  path: string;
  name: string;
  totalMB: number;
  usedMB: number;
  percentUsed: number;
}

export interface NamespaceInfo {
  name: string;
  directory: string;
}

export interface ProcessRow {
  pid: number;
  userName: string;
  namespace: string;
  routine: string;
  state: string;
  cpuTime: number;
  memoryUsedKB: number;
  globalReferences: number;
  clientIP: string;
  jobType: number;
  canBeTerminated: boolean;
  startTimeUTC: string;
}

@Injectable({ providedIn: 'root' })
export class SystemService {
  constructor(private api: ApiService) {}

  metrics(): Observable<Metrics> {
    return this.api.get<Metrics>('/system/metrics');
  }

  disks(): Observable<Disk[]> {
    return this.api.get<Disk[]>('/system/disks');
  }

  namespaces(): Observable<NamespaceInfo[]> {
    return this.api.get<NamespaceInfo[]>('/system/namespaces');
  }

  processes(namespace?: string): Observable<ProcessRow[]> {
    return this.api.get<ProcessRow[]>('/system/processes', namespace ? { namespace } : undefined);
  }

  terminate(pid: number): Observable<{ ok: boolean }> {
    return this.api.post<{ ok: boolean }>(`/system/processes/${pid}/terminate`);
  }
}