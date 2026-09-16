import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../core/api.service';

export interface LogSource {
  name: string;
  available: boolean;
}

export interface LogEntry {
  timestamp: string;
  severity: string;
  source: string;
  message: string;
  detail: string;
  job: string;
  user: string;
}

export interface LogQueryResult {
  entries: LogEntry[];
  total: number;
}

export interface LogFilter {
  source?: string;
  from?: string;
  to?: string;
  severity?: string;
  pageSize?: number;
}

@Injectable({ providedIn: 'root' })
export class LogsService {
  constructor(private api: ApiService) {}

  sources(): Observable<LogSource[]> {
    return this.api.get<LogSource[]>('/logs/sources');
  }

  query(filter?: LogFilter): Observable<LogQueryResult> {
    return this.api.get<LogQueryResult>('/logs', filter as Record<string, string | number>);
  }

  exportUrl(filter?: LogFilter): string {
    let url = this.api.url('/logs/export');
    if (filter) {
      const parts: string[] = [];
      for (const key of Object.keys(filter)) {
        const value = (filter as Record<string, unknown>)[key];
        if (value !== undefined && value !== null && value !== '') {
          parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
        }
      }
      if (parts.length > 0) url += `?${parts.join('&')}`;
    }
    return url;
  }
}
