import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Observable } from 'rxjs';
import { Task, TaskHistoryEntry, TasksService } from './tasks.service';

@Component({
  selector: 'mp-tasks',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="page-header">
      <div>
        <h1>Tasks</h1>
        <div class="muted">Scheduled task definitions, history and control.</div>
      </div>
      <button (click)="reload()">Refresh</button>
    </div>

    <div *ngIf="error" class="alert alert-error">{{ error }}</div>
    <div *ngIf="info" class="alert alert-info">{{ info }}</div>

    <div class="card">
      <h2>Scheduled tasks</h2>
      <table>
        <thead>
          <tr>
            <th>Name</th><th>Status</th><th>Next run</th><th>Last run</th><th>Frequency</th><th>Namespace</th><th>Run as</th><th></th>
          </tr>
        </thead>
        <tbody>
          <tr *ngFor="let t of tasks">
            <td>
              <strong>{{ t.name }}</strong>
              <div class="muted" style="font-size:11px">{{ t.taskClass || t.description }}</div>
            </td>
            <td>
              <span class="badge" [ngClass]="statusClass(t)">{{ t.status }}</span>
            </td>
            <td class="tag">{{ t.nextScheduled || '—' }}</td>
            <td class="tag">{{ t.lastFinished || '—' }}</td>
            <td class="tag">{{ t.frequency || 'Scheduled' }}</td>
            <td>{{ t.namespace }}</td>
            <td>{{ t.runAsUser }}</td>
            <td>
              <button class="btn-sm" [disabled]="busy[t.guid]" (click)="run(t)">Run now</button>
              <button class="btn-sm" [disabled]="busy[t.guid]" (click)="t.enabled ? suspend(t) : resume(t)">
                {{ t.enabled ? 'Suspend' : 'Resume' }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <div *ngIf="tasks.length === 0 && !loading" class="muted" style="padding:8px 0">No scheduled tasks found.</div>
    </div>

    <div class="card">
      <h2>Execution history</h2>
      <table>
        <thead>
          <tr><th>Task</th><th>Status</th><th>Started</th><th>Finished</th><th>Error / output</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let h of history">
            <td>{{ h.name || h.guid }}</td>
            <td><span class="badge" [ngClass]="h.error || h.status === 'Failed' ? 'badge-red' : 'badge-green'">{{ h.status || 'Finished' }}</span></td>
            <td class="tag">{{ h.startTime || '—' }}</td>
            <td class="tag">{{ h.finishTime || '—' }}</td>
            <td class="tag">{{ h.error || h.output || '—' }}</td>
          </tr>
        </tbody>
      </table>
      <div *ngIf="history.length === 0 && !loading" class="muted" style="padding:8px 0">No task history recorded yet.</div>
    </div>
  `,
})
export class TasksComponent implements OnInit {
  tasks: Task[] = [];
  history: TaskHistoryEntry[] = [];
  busy: Record<string, boolean> = {};
  loading = false;
  error = '';
  info = '';

  constructor(private service: TasksService) {}

  ngOnInit(): void {
    this.reload();
  }

  reload(): void {
    this.loading = true;
    this.info = '';
    this.service.list().subscribe({
      next: (tasks) => {
        this.tasks = tasks;
        this.loading = false;
        this.service.history().subscribe({
          next: (history) => (this.history = history),
          error: (e) => (this.error = this.message(e)),
        });
      },
      error: (e) => {
        this.loading = false;
        this.error = this.message(e);
      },
    });
  }

  statusClass(t: Task): string {
    if (t.status === 'Suspended' || !t.enabled) return 'badge-yellow';
    return 'badge-green';
  }

  run(t: Task): void {
    this.action(this.service.run(t.guid), `Task "${t.name}" scheduled to run now.`);
  }

  suspend(t: Task): void {
    this.action(this.service.suspend(t.guid), `Task "${t.name}" suspended.`);
  }

  resume(t: Task): void {
    this.action(this.service.resume(t.guid), `Task "${t.name}" resumed.`);
  }

  private action(obs: Observable<{ ok: boolean }>, success: string): void {
    this.error = '';
    obs.subscribe({
      next: () => {
        this.info = success;
        this.reload();
      },
      error: (e) => (this.error = this.message(e)),
    });
  }

  private message(e: unknown): string {
    const body = (e as { error?: { message?: string } }).error;
    return body?.message ?? 'Request failed.';
  }
}