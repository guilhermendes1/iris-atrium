import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { WebApp, WebappsService } from './webapps.service';

@Component({
  selector: 'mp-webapps',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  template: `
    <div class="page-header">
      <div>
        <h1>Web Apps</h1>
        <div class="muted">All configured CSP / REST web applications on this instance.</div>
      </div>
      <div>
        <button class="btn-primary" (click)="toggleForm()">{{ showForm ? 'Cancel' : 'New web app' }}</button>
        <a routerLink="/webapps/explorer"><button>API Explorer</button></a>
      </div>
    </div>

    <div *ngIf="error" class="alert alert-error">{{ error }}</div>
    <div *ngIf="info" class="alert alert-info">{{ info }}</div>

    <div class="card" *ngIf="showForm">
      <h2>Create web application</h2>
      <div class="form-group">
        <div class="form-row">
          <label>Name (path)</label>
          <input [(ngModel)]="form.name" placeholder="/csp/myapp" />
        </div>
        <div class="form-row">
          <label>Namespace</label>
          <input [(ngModel)]="form.namespace" placeholder="MANAGEMENT" />
        </div>
        <div class="form-row">
          <label>Physical path (CSP only)</label>
          <input [(ngModel)]="form.path" placeholder="/opt/mgmt/csp" />
        </div>
        <div class="form-row">
          <label>Dispatch class (REST only)</label>
          <input [(ngModel)]="form.dispatchClass" placeholder="" />
        </div>
        <div class="form-row">
          <label>Authentication</label>
          <select [(ngModel)]="form.authentication">
            <option value="Unauthenticated">Unauthenticated</option>
            <option value="Password">Password</option>
            <option value="Server">Server</option>
            <option value="Delegated">Delegated</option>
            <option value="Kerberos">Kerberos</option>
          </select>
        </div>
        <div class="form-row" style="margin-top:22px">
          <button class="btn-primary" (click)="create()" [disabled]="busy">Create</button>
        </div>
      </div>
    </div>

    <table>
      <thead>
        <tr>
          <th>Path</th>
          <th>Type</th>
          <th>Status</th>
          <th>Namespace</th>
          <th>Authentication</th>
          <th>Dispatch class</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr *ngFor="let app of apps">
          <td><strong>{{ app.path }}</strong></td>
          <td><span class="badge" [ngClass]="badgeClass(app.type)">{{ app.type }}</span></td>
          <td>
            <span class="badge" [ngClass]="app.enabled ? 'badge-green' : 'badge-red'">{{ app.enabled ? 'Enabled' : 'Disabled' }}</span>
          </td>
          <td>{{ app.namespace }}</td>
          <td>{{ app.authentication || '—' }}</td>
          <td class="muted">{{ app.dispatchClass || '—' }}</td>
          <td>
            <button class="btn-sm btn-danger" (click)="remove(app)" title="Delete this web application">Delete</button>
          </td>
        </tr>
      </tbody>
    </table>
  `,
})
export class WebappsComponent implements OnInit {
  apps: WebApp[] = [];
  showForm = false;
  busy = false;
  error = '';
  info = '';

  form = { name: '', namespace: 'MANAGEMENT', path: '/opt/mgmt/csp', dispatchClass: '', authentication: 'Unauthenticated' };

  constructor(private service: WebappsService) {}

  ngOnInit(): void {
    this.reload();
  }

  reload(): void {
    this.error = '';
    this.service.list().subscribe({
      next: (apps) => (this.apps = apps),
      error: (e) => (this.error = this.message(e)),
    });
  }

  badgeClass(type: string): string {
    if (type === 'REST') return 'badge-blue';
    if (type === 'CSP') return 'badge-green';
    return 'badge-gray';
  }

  toggleForm(): void {
    this.showForm = !this.showForm;
  }

  create(): void {
    if (!this.form.name) {
      this.error = 'Name is required.';
      return;
    }
    this.busy = true;
    this.error = '';
    const props: Record<string, unknown> = {
      namespace: this.form.namespace,
      path: this.form.path,
      dispatchClass: this.form.dispatchClass,
      authentication: this.form.authentication,
      enabled: 1,
      serving: this.form.dispatchClass ? 0 : 1,
    };
    this.service.create(this.form.name, props).subscribe({
      next: () => {
        this.busy = false;
        this.showForm = false;
        this.info = `Web app ${this.form.name} created.`;
        this.reload();
      },
      error: (e) => {
        this.busy = false;
        this.error = this.message(e);
      },
    });
  }

  remove(app: WebApp): void {
    if (!window.confirm(`Delete web application ${app.path}?`)) return;
    this.service.remove(app.name).subscribe({
      next: () => {
        this.info = `Web app ${app.path} deleted.`;
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