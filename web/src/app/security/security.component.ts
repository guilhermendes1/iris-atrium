import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Credential, SecurityService } from './security.service';

@Component({
  selector: 'mp-security',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="page-header">
      <div>
        <h1>Security &amp; Secrets</h1>
        <div class="muted">SSL configs, X.509 credentials, wallets and OAuth clients (read-only).</div>
      </div>
    </div>

    <div *ngIf="error" class="alert alert-error">{{ error }}</div>
    <div *ngIf="info" class="alert alert-info">{{ info }}</div>

    <div class="tabs" style="margin-bottom:12px">
      <button [class.active]="type==='all'" (click)="setType('all')">All</button>
      <button [class.active]="type==='ssl'" (click)="setType('ssl')">SSL</button>
      <button [class.active]="type==='x509'" (click)="setType('x509')">X.509</button>
      <button [class.active]="type==='wallet'" (click)="setType('wallet')">Wallets</button>
      <button [class.active]="type==='oauth'" (click)="setType('oauth')">OAuth</button>
    </div>

    <div class="card">
      <table>
        <thead>
          <tr><th>Type</th><th>Alias</th><th>Status</th><th>Issuer</th><th>Subject</th><th>Expires</th><th></th></tr>
        </thead>
        <tbody>
          <tr *ngFor="let c of items">
            <td><span class="badge badge-blue">{{ c.type }}</span></td>
            <td><strong>{{ c.alias }}</strong></td>
            <td><span class="badge" [ngClass]="c.enabled ? 'badge-green' : 'badge-gray'">{{ c.status || 'Active' }}</span></td>
            <td class="tag">{{ c.issuer || '—' }}</td>
            <td class="tag">{{ c.subject || '—' }}</td>
            <td class="tag">{{ c.validTo || '—' }}</td>
            <td><button class="btn-sm" (click)="showDetail(c)" [disabled]="busy[c.alias]">Details</button></td>
          </tr>
        </tbody>
      </table>
      <div *ngIf="items.length === 0 && !loading" class="muted" style="padding:8px 0">No credentials of this type found on the instance.</div>
    </div>

    <div class="card" *ngIf="detail">
      <h2>Credential details — {{ detail.alias }}</h2>
      <table>
        <tbody>
          <tr *ngFor="let key of detailKeys">
            <td style="width:160px"><strong>{{ key }}</strong></td>
            <td>{{ val(key) }}</td>
          </tr>
        </tbody>
      </table>
      <button style="margin-top:8px" (click)="detail=null">Close</button>
    </div>
  `,
  styles: [
    `
      .tabs button { margin-right: 6px; }
      .tabs button.active { background: var(--mp-accent); color: #fff; border-color: var(--mp-accent); }
    `,
  ],
})
export class SecurityComponent implements OnInit {
  type = 'all';
  items: Credential[] = [];
  detail: Credential | null = null;
  detailKeys: string[] = [];
  loading = false;
  busy: Record<string, boolean> = {};
  error = '';
  info = '';

  constructor(private service: SecurityService) {}

  ngOnInit(): void {
    this.setType('all');
  }

  setType(type: string): void {
    this.type = type;
    this.loading = true;
    this.service.credentials(type === 'all' ? undefined : type).subscribe({
      next: (items) => {
        this.loading = false;
        this.items = items;
        this.detail = null;
      },
      error: (e) => {
        this.loading = false;
        this.error = this.message(e);
      },
    });
  }

  showDetail(c: Credential): void {
    this.busy[c.alias] = true;
    this.service.detail(c.type, c.alias).subscribe({
      next: (d) => {
        this.busy[c.alias] = false;
        this.detail = d;
        this.detailKeys = Object.keys(d ?? {});
      },
      error: (e) => {
        this.busy[c.alias] = false;
        this.error = this.message(e);
      },
    });
  }

  private message(e: unknown): string {
    const body = (e as { error?: { message?: string } }).error;
    return body?.message ?? 'Request failed.';
  }

  val(key: string): string {
    const v = (this.detail as Record<string, unknown> | null)?.[key];
    return v !== null && v !== '' && v !== undefined ? String(v) : '—';
  }
}