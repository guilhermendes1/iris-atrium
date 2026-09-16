import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Disk, Metrics, NamespaceInfo, ProcessRow, SystemService } from './system.service';

@Component({
  selector: 'mp-system',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page-header">
      <div>
        <h1>Operating System</h1>
        <div class="muted">Live health snapshot of the IRIS container.</div>
      </div>
      <button (click)="reload()">Refresh</button>
    </div>

    <div *ngIf="error" class="alert alert-error">{{ error }}</div>
    <div *ngIf="info" class="alert alert-info">{{ info }}</div>

    <div class="cards">
      <div class="card metric">
        <div class="metric-label">CPU</div>
        <div class="metric-value">{{ metrics.cpuPercent }}%</div>
      </div>
      <div class="card metric">
        <div class="metric-label">Memory</div>
        <div class="metric-value">{{ metrics.memoryPercent }}%</div>
        <div class="metric-sub">{{ kb(metrics.memoryUsedKB) }} / {{ kb(metrics.memoryTotalKB) }}</div>
      </div>
      <div class="card metric">
        <div class="metric-label">Uptime</div>
        <div class="metric-value">{{ uptime() }}</div>
      </div>
      <div class="card metric">
        <div class="metric-label">Namespaces</div>
        <div class="metric-value">{{ namespaces.length }}</div>
      </div>
    </div>

    <div class="card">
      <h2>Disk space</h2>
      <table>
        <thead><tr><th>Directory</th><th>Total</th><th>Used</th><th>Usage</th><th style="width:30%">Bar</th></tr></thead>
        <tbody>
          <tr *ngFor="let d of disks">
            <td class="tag">{{ d.path }}</td>
            <td>{{ mb(d.totalMB) }}</td>
            <td>{{ mb(d.usedMB) }}</td>
            <td>{{ d.percentUsed }}%</td>
            <td>
              <div class="bar"><div class="bar-fill" [style.width.%]="d.percentUsed || 0"></div></div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Namespaces</h2>
      <table>
        <thead><tr><th>Name</th><th>Directory</th></tr></thead>
        <tbody>
          <tr *ngFor="let n of namespaces">
            <td><strong>{{ n.name }}</strong></td>
            <td class="tag">{{ n.directory || '—' }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card">
      <h2>Processes</h2>
      <table>
        <thead>
          <tr><th>PID</th><th>User</th><th>Namespace</th><th>Routine</th><th>State</th><th>Memory</th><th>Client IP</th><th></th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let p of processes">
            <td class="tag">{{ p.pid }}</td>
            <td>{{ p.userName }}</td>
            <td>{{ p.namespace }}</td>
            <td class="tag">{{ p.routine }}</td>
            <td><span class="badge badge-blue">{{ p.state }}</span></td>
            <td class="tag">{{ kb(p.memoryUsedKB) }}</td>
            <td class="tag">{{ p.clientIP || '—' }}</td>
            <td><button class="btn-sm btn-danger" (click)="terminate(p)">Terminate</button></td>
          </tr>
        </tbody>
      </table>
    </div>
  `,
  styles: [
    `
      .cards { display: flex; gap: 12px; margin-bottom: 16px; flex-wrap: wrap; }
      .card.metric { flex: 1 1 180px; text-align: center; margin-bottom: 0; }
      .metric-label { color: var(--mp-muted); font-size: 12px; text-transform: uppercase; }
      .metric-value { font-size: 28px; font-weight: 700; margin: 4px 0; }
      .metric-sub { color: var(--mp-muted); font-size: 12px; }
      .bar { height: 8px; background: #eef1f5; border-radius: 4px; overflow: hidden; }
      .bar-fill { height: 100%; background: var(--mp-accent); }
    `,
  ],
})
export class SystemComponent implements OnInit {
  metrics: Metrics = { cpuPercent: 0, memoryTotalKB: 0, memoryUsedKB: 0, memoryPercent: 0, uptimeSeconds: 0 };
  disks: Disk[] = [];
  namespaces: NamespaceInfo[] = [];
  processes: ProcessRow[] = [];
  error = '';
  info = '';

  constructor(private service: SystemService) {}

  ngOnInit(): void {
    this.reload();
  }

  reload(): void {
    this.service.metrics().subscribe({ next: (m) => (this.metrics = m), error: (e) => (this.error = this.message(e)) });
    this.service.disks().subscribe({ next: (d) => (this.disks = d), error: () => undefined });
    this.service.namespaces().subscribe({ next: (n) => (this.namespaces = n), error: () => undefined });
    this.service.processes().subscribe({ next: (p) => (this.processes = p), error: (e) => (this.error = this.message(e)) });
  }

  kb(value: number): string {
    return `${(value ?? 0).toLocaleString()} KB`;
  }

  mb(value: number): string {
    return `${(value ?? 0).toLocaleString()} MB`;
  }

  uptime(): string {
    const s = this.metrics.uptimeSeconds ?? 0;
    if (s <= 0) return '—';
    const d = Math.floor(s / 86400);
    const h = Math.floor((s % 86400) / 3600);
    const m = Math.floor((s % 3600) / 60);
    return d > 0 ? `${d}d ${h}h ${m}m` : `${h}h ${m}m`;
  }

  terminate(p: ProcessRow): void {
    if (!window.confirm(`Terminate process ${p.pid} (${p.userName} / ${p.routine})?`)) return;
    this.service.terminate(p.pid).subscribe({
      next: () => {
        this.info = `Termination request for process ${p.pid} accepted.`;
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