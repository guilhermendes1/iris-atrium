import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PermissionsService, ResourceRow, RoleRow, UserRow } from './permissions.service';

@Component({
  selector: 'mp-permissions',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
    <div class="page-header">
      <div>
        <h1>Permissions</h1>
        <div class="muted">IRIS users, roles and security resources.</div>
      </div>
    </div>

    <div *ngIf="error" class="alert alert-error">{{ error }}</div>
    <div *ngIf="info" class="alert alert-info">{{ info }}</div>

    <div class="tabs" style="margin-bottom:12px">
      <button [class.active]="tab==='users'" (click)="tab='users'">Users</button>
      <button [class.active]="tab==='roles'" (click)="tab='roles'" (click)="loadRoles()">Roles</button>
      <button [class.active]="tab==='resources'" (click)="tab='resources'" (click)="loadResources()">Resources</button>
    </div>

    <!-- Users -->
    <ng-container *ngIf="tab==='users'">
      <div class="card" *ngIf="!editing">
        <h2>Users</h2>
        <table>
          <thead>
            <tr><th>Username</th><th>Full name</th><th>Status</th><th>Roles</th><th>Last login</th><th></th></tr>
          </thead>
          <tbody>
            <tr *ngFor="let u of users">
              <td><strong>{{ u.username }}</strong></td>
              <td>{{ u.fullName || '—' }}</td>
              <td><span class="badge" [ngClass]="u.enabled ? 'badge-green' : 'badge-red'">{{ u.enabled ? 'Enabled' : 'Disabled' }}</span></td>
              <td>
                <span *ngFor="let r of u.roles" class="badge badge-blue" style="margin-right:4px">{{ r }}</span>
                <span *ngIf="!u.roles || u.roles.length === 0" class="muted">no roles</span>
              </td>
              <td class="tag">{{ u.lastLogin || '—' }}</td>
              <td>
                <button class="btn-sm" (click)="edit(u)">Edit roles</button>
                <button class="btn-sm" (click)="toggleDisabled(u)">{{ u.enabled ? 'Disable' : 'Enable' }}</button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="card" *ngIf="editing">
        <h2>Edit roles — {{ editing.username }}</h2>
        <div class="form-group" *ngIf="roles.length > 0">
          <div *ngFor="let r of roles" class="form-row" style="flex:unset; min-width:200px">
            <label>
              <input type="checkbox" [checked]="editingRoles.includes(r.name)" (change)="toggleRole(r.name)" /> {{ r.name }}
            </label>
          </div>
        </div>
        <div *ngIf="roles.length === 0" class="muted">Loading role list…</div>
        <div style="margin-top:12px">
          <button class="btn-primary" (click)="saveRoles()" [disabled]="busy">Save</button>
          <button (click)="editing=null" style="margin-left:6px">Cancel</button>
        </div>
      </div>
    </ng-container>

    <!-- Roles -->
    <ng-container *ngIf="tab==='roles'">
      <div class="card">
        <h2>Roles</h2>
        <table>
          <thead><tr><th>Name</th><th>Description</th><th>Resources</th></tr></thead>
          <tbody>
            <tr *ngFor="let r of roles">
              <td><strong>{{ r.name }}</strong></td>
              <td>{{ r.description || '—' }}</td>
              <td>
                <span *ngFor="let res of r.resources" class="badge badge-gray" style="margin:0 4px 4px 0">{{ res.resource }} {{ res.permission }}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </ng-container>

    <!-- Resources -->
    <ng-container *ngIf="tab==='resources'">
      <div class="card">
        <h2>Resources</h2>
        <table>
          <thead><tr><th>Name</th><th>Description</th><th>Public</th><th>Type</th></tr></thead>
          <tbody>
            <tr *ngFor="let r of resources">
              <td><strong>{{ r.name }}</strong></td>
              <td>{{ r.description || '—' }}</td>
              <td>{{ r.publicPermission || '—' }}</td>
              <td>{{ r.type || '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </ng-container>
  `,
  styles: [
    `
      .tabs button { margin-right: 6px; }
      .tabs button.active { background: var(--mp-accent); color: #fff; border-color: var(--mp-accent); }
    `,
  ],
})
export class PermissionsComponent implements OnInit {
  tab: 'users' | 'roles' | 'resources' = 'users';
  users: UserRow[] = [];
  roles: RoleRow[] = [];
  resources: ResourceRow[] = [];
  editing: UserRow | null = null;
  editingRoles: string[] = [];
  busy = false;
  error = '';
  info = '';

  constructor(private service: PermissionsService) {}

  ngOnInit(): void {
    this.loadUsers();
    this.loadRoles();
  }

  loadUsers(): void {
    this.service.users().subscribe({
      next: (users) => (this.users = users),
      error: (e) => (this.error = this.message(e)),
    });
  }

  loadRoles(): void {
    if (this.roles.length > 0) return;
    this.service.rolesList().subscribe({
      next: (roles) => (this.roles = roles),
      error: (e) => (this.error = this.message(e)),
    });
  }

  loadResources(): void {
    this.service.resources().subscribe({
      next: (resources) => (this.resources = resources),
      error: (e) => (this.error = this.message(e)),
    });
  }

  edit(u: UserRow): void {
    this.editing = u;
    this.editingRoles = [...(u.roles ?? [])];
    this.loadRoles();
    this.error = '';
  }

  toggleRole(name: string): void {
    const i = this.editingRoles.indexOf(name);
    if (i >= 0) this.editingRoles.splice(i, 1);
    else this.editingRoles.push(name);
  }

  saveRoles(): void {
    if (!this.editing) return;
    this.busy = true;
    this.service.setUserRoles(this.editing.username, this.editingRoles).subscribe({
      next: () => {
        this.busy = false;
        this.info = `Roles updated for ${this.editing!.username}.`;
        const username = this.editing!.username;
        this.editing = null;
        this.loadUsers();
        const u = this.users.find((x) => x.username === username);
        if (u) u.roles = [...this.editingRoles];
      },
      error: (e) => {
        this.busy = false;
        this.error = this.message(e);
      },
    });
  }

  toggleDisabled(u: UserRow): void {
    this.service.setUserEnabled(u.username, !u.enabled).subscribe({
      next: () => {
        u.enabled = !u.enabled;
        this.info = `${u.username} ${u.enabled ? 'enabled' : 'disabled'}.`;
      },
      error: (e) => (this.error = this.message(e)),
    });
  }

  private message(e: unknown): string {
    const body = (e as { error?: { message?: string } }).error;
    return body?.message ?? 'Request failed.';
  }
}