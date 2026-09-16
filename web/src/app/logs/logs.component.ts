import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { LogEntry, LogSource, LogsService } from './logs.service';

@Component({
  selector: 'mp-logs',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page-header">
      <div>
        <h1>Logs</h1>
        <div class="muted">Unified console, messages, audit and task-history log viewer.</div>
      </div>
      <button (click)="reload()">Refresh</button>
    </div>

    <div *ngIf="error" class="alert alert-error">{{ error }}</div>

    <div class="card">
      <div class="form-group">
        <div class="form-row">
          <label>Source</label>
          <select [(ngModel)]="filter.source">
            <option value="">All sources</option>
            <option *ngFor="let s of sources" [value]="s.name" [disabled]="!s.available">
              {{ s.name }}{{ s.available ? '' : ' (unavailable)' }}
            </option>
          </select>
        </div>
        <div class="form-row">
          <label>Severity</label>
          <select [(ngModel)]="filter.severity">
            <option value="">All severities</option>
            <option value="Info">Info</option>
            <option value="Warning">Warning</option>
            <option value="Error">Error</option>
            <option value="Debug">Debug</option>
          </select>
        </div>
        <div class="form-row">
          <label>From</label>
          <input type="datetime-local" [(ngModel)]="filter.from" />
        </div>
        <div class="form-row">
          <label>To</label>
          <input type="datetime-local" [(ngModel)]="filter.to" />
        </div>
        <div class="form-row">
          <label>Page size</label>
          <input type="number" min="1" max="5000" [(ngModel)]="filter.pageSize" />
        </div>
      </div>
      <div style="margin-top:8px">
        <button class="btn-primary" (click)="reload()" [disabled]="loading">Query</button>
        <button (click)="exportCsv()" style="margin-left:6px" [disabled]="loading">Export CSV</button>
        <button (click)="reset()" style="margin-left:6px">Reset</button>
      </div>
    </div>

    <div class="card">
      <div class="page-header" style="margin-bottom:8px">
        <h2>Entries</h2>
        <span class="tag">{{ total }} match(es) · showing {{ entries.length }}</span>
      </div>
      <table>
        <thead>
          <tr><th>Timestamp</th><th>Severity</th><th>Source</th><th>Message</th><th>Job</th><th>User</th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let e of entries">
            <td class="tag">{{ e.timestamp || '—' }}</td>
            <td><span class="badge" [ngClass]="severityClass(e.severity)">{{ e.severity }}</span></td>
            <td>{{ e.source }}</td>
            <td>
              {{ e.message || '—' }}
              <div *ngIf="e.detail" class="muted" style="font-size:11px">{{ e.detail }}</div>
            </td>
            <td class="tag">{{ e.job || '—' }}</td>
            <td class="tag">{{ e.user || '—' }}</td>
          </tr>
        </tbody>
      </table>
      <div *ngIf="entries.length === 0 && !loading" class="muted" style="padding:8px 0">No log entries matched the current filters.</div>
    </div>
  `,
})
export class LogsComponent implements OnInit {
  sources: LogSource[] = [];
  entries: LogEntry[] = [];
  total = 0;
  loading = false;
  error = '';

  filter = {
    source: '',
    severity: '',
    from: '',
    to: '',
    pageSize: 200,
  };

  constructor(private service: LogsService) {}

  ngOnInit(): void {
    this.service.sources().subscribe({
      next: (sources) => (this.sources = sources),
      error: (e) => (this.error = this.message(e)),
    });
    this.reload();
  }

  reload(): void {
    this.loading = true;
    this.error = '';
    this.service.query(this.activeFilter()).subscribe({
      next: (result) => {
        this.loading = false;
        this.entries = result.entries ?? [];
        this.total = result.total ?? this.entries.length;
      },
      error: (e) => {
        this.loading = false;
        this.error = this.message(e);
      },
    });
  }

  exportCsv(): void {
    window.open(this.service.exportUrl(this.activeFilter()), '_blank');
  }

  reset(): void {
    this.filter = { source: '', severity: '', from: '', to: '', pageSize: 200 };
    this.reload();
  }

  private activeFilter(): Record<string, string | number> {
    const f: Record<string, string | number> = {};
    if (this.filter.source) f['source'] = this.filter.source;
    if (this.filter.severity) f['severity'] = this.filter.severity;
    if (this.filter.from) f['from'] = this.filter.from;
    if (this.filter.to) f['to'] = this.filter.to;
    if (this.filter.pageSize) f['pageSize'] = this.filter.pageSize;
    return f;
  }

  severityClass(severity: string): string {
    switch (severity) {
      case 'Error':
        return 'badge-red';
      case 'Warning':
        return 'badge-yellow';
      case 'Debug':
        return 'badge-gray';
      default:
        return 'badge-blue';
    }
  }

  private message(e: unknown): string {
    const body = (e as { error?: { message?: string } }).error;
    return body?.message ?? 'Request failed.';
  }
}
