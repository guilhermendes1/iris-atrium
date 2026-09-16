import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';
import { ApiService } from '../core/api.service';

export interface Task {
  guid: string;
  name: string;
  description: string;
  namespace: string;
  taskClass: string;
  frequency: string;
  runAsUser: string;
  enabled: boolean;
  status: string;
  nextScheduled: string;
  lastStarted: string;
  lastFinished: string;
  error: string;
}

export interface TaskHistoryEntry {
  guid: string;
  name: string;
  startTime: string;
  finishTime: string;
  status: string;
  error: string;
  output: string;
}

@Injectable({ providedIn: 'root' })
export class TasksService {
  constructor(private api: ApiService) {}

  list(): Observable<Task[]> {
    return this.api.get<Task[]>('/tasks');
  }

  history(guid?: string): Observable<TaskHistoryEntry[]> {
    return this.api.get<TaskHistoryEntry[]>('/tasks/history', guid ? { guid } : undefined);
  }

  run(guid: string): Observable<{ ok: boolean }> {
    return this.api.post<{ ok: boolean }>(`/tasks/${encodeURIComponent(guid)}/run`);
  }

  suspend(guid: string): Observable<{ ok: boolean }> {
    return this.api.put<{ ok: boolean }>(`/tasks/${encodeURIComponent(guid)}/suspend`);
  }

  resume(guid: string): Observable<{ ok: boolean }> {
    return this.api.put<{ ok: boolean }>(`/tasks/${encodeURIComponent(guid)}/resume`);
  }
}