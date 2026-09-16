import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient, HttpResponse } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { InstalledApp, WebappsService } from './webapps.service';

interface SpecOperation {
  method: string;
  path: string;
  summary?: string;
}

@Component({
  selector: 'mp-explorer',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page-header">
      <div>
        <h1>API Explorer</h1>
        <div class="muted">REST-enabled applications discovered via the native /api/mgmnt endpoint.</div>
      </div>
    </div>

    <div *ngIf="error" class="alert alert-error">{{ error }}</div>

    <div class="card">
      <h2>Installed REST apps</h2>
      <div *ngIf="apps.length === 0 && !loading" class="muted">No REST-enabled applications found, or the instance returned none.</div>
      <table *ngIf="apps.length > 0">
        <thead>
          <tr><th>App</th><th>Namespace</th><th>Dispatch class</th><th>Status</th><th></th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let app of apps">
            <td><strong>{{ app.name }}</strong></td>
            <td>{{ app.namespace }}</td>
            <td class="muted">{{ app.dispatchClass || '—' }}</td>
            <td>
              <span class="badge" [ngClass]="app.enabled ? 'badge-green' : 'badge-red'">{{ app.enabled ? 'Enabled' : 'Disabled' }}</span>
            </td>
            <td><button class="btn-sm" (click)="loadSpec(app)" [disabled]="busy">Open spec</button></td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="card" *ngIf="spec">  
      <div class="page-header" style="margin-bottom:8px">
        <div>
          <h2>OpenAPI spec — {{ selected?.name }}</h2>
          <div class="muted">{{ spec.info?.title }} · {{ spec.info?.version }}</div>
        </div>
        <div>
          <span class="tag">{{ operations.length }} GET operation(s) available for testing</span>
        </div>
      </div>

      <div class="form-group" style="margin-bottom:12px" *ngIf="operations.length > 0">
        <div class="form-row" style="flex:3">
          <label>Operation</label>
          <select [(ngModel)]="selectedOp" (ngModelChange)="result = null">
            <option *ngFor="let op of operations" [ngValue]="op">{{ op.method }} {{ op.path }} {{ op.summary ? '— ' + op.summary : '' }}</option>
          </select>
        </div>
        <div class="form-row" style="margin-top:22px">
          <button class="btn-primary" (click)="runTest()" [disabled]="!selectedOp">Test request</button>
        </div>
      </div>

      <div *ngIf="result" class="alert" [ngClass]="result.status >= 200 && result.status < 300 ? 'alert-info' : 'alert-error'">
        <strong>HTTP {{ result.status }}</strong>
        <pre style="white-space:pre-wrap; margin:8px 0 0 0">{{ result.body }}</pre>
      </div>

      <h3 style="margin-top:16px">Raw specification</h3>
      <pre class="spec">{{ specJson }}</pre>
    </div>
  `,
})
export class ExplorerComponent implements OnInit {
  apps: InstalledApp[] = [];
  selected?: InstalledApp;
  spec: any = null;
  specJson = '';
  operations: SpecOperation[] = [];
  selectedOp?: SpecOperation;
  result: { status: number; body: string } | null = null;
  loading = true;
  busy = false;
  error = '';

  constructor(private service: WebappsService, private http: HttpClient) {}

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.loading = true;
    this.service.installed().subscribe({
      next: (res) => {
        this.loading = false;
        this.apps = res.apps ?? [];
        if (!res.ok) this.error = res.raw || 'Discovery failed.';
      },
      error: (e) => {
        this.loading = false;
        this.error = this.message(e);
      },
    });
  }

  loadSpec(app: InstalledApp): void {
    this.busy = true;
    this.error = '';
    this.result = null;
    this.service.spec(app.namespace, app.name).subscribe({
      next: (text) => {
        this.busy = false;
        this.selected = app;
        this.specJson = text;
        try {
          this.spec = JSON.parse(text);
          this.operations = this.collectOperations(this.spec);
          this.selectedOp = this.operations.find((o) => o.path.startsWith(app.name)) ?? this.operations[0];
        } catch {
          this.spec = null;
          this.operations = [];
        }
      },
      error: (e) => {
        this.busy = false;
        this.error = this.message(e);
      },
    });
  }

  private collectOperations(spec: any): SpecOperation[] {
    const ops: SpecOperation[] = [];
    const paths = spec?.paths ?? {};
    for (const path of Object.keys(paths)) {
      const methods = ['get', 'post', 'put', 'delete', 'patch'];
      for (const method of methods) {
        if (paths[path][method]) {
          ops.push({ method: method.toUpperCase(), path, summary: paths[path][method].summary ?? '' });
        }
      }
    }
    return ops.filter((o) => o.method === 'GET' && !/{/g.test(o.path));
  }

  runTest(): void {
    const op = this.selectedOp;
    if (!op || !this.selected) return;
    const path = `${this.selected.name}${op.path}`;
    this.http.get(path, { observe: 'response', responseType: 'text' }).subscribe({
      next: (res: HttpResponse<string>) => {
        this.result = { status: res.status, body: res.body ?? '' };
      },
      error: (e) => {
        const status = e?.status ?? 0;
        this.result = { status, body: e?.error ?? e?.message ?? 'Request failed.' };
      },
    });
  }

  private message(e: unknown): string {
    const body = (e as { error?: { message?: string } }).error;
    return body?.message ?? 'Request failed.';
  }
}