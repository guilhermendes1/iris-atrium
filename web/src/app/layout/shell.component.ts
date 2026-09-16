import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';
import { SessionService } from '../core/session.service';

@Component({
  selector: 'mp-shell',
  standalone: true,
  imports: [CommonModule, RouterModule],
  template: `
    <div class="shell">
      <aside class="sidebar">
        <div class="brand">
          <div class="logo">IA</div>
          <div>
            <div class="brand-name">IRIS Atrium</div>
            <div class="brand-sub">InterSystems IRIS</div>
          </div>
        </div>
        <nav>
          <a routerLink="/webapps" routerLinkActive="active" [routerLinkActiveOptions]="{exact:true}">Web Apps</a>
          <a routerLink="/webapps/explorer" routerLinkActive="active">API Explorer</a>
          <a routerLink="/permissions" routerLinkActive="active">Permissions</a>
          <a routerLink="/security" routerLinkActive="active">Security &amp; Secrets</a>
          <a routerLink="/tasks" routerLinkActive="active">Tasks</a>
          <a routerLink="/system" routerLinkActive="active">OS Management</a>
          <a routerLink="/logs" routerLinkActive="active">Logs</a>
        </nav>
      </aside>
      <div class="main">
        <header class="topbar">
          <span class="topbar-title">IRIS Administration Console</span>
          <span class="spacer"></span>
          <span class="muted">Signed in as <strong>{{ session.username }}</strong></span>
          <button class="btn-sm" (click)="logout()">Sign out</button>
        </header>
        <main class="content">
          <router-outlet></router-outlet>
        </main>
      </div>
    </div>
  `,
  styles: [
    `
      .shell { display: flex; height: 100vh; }
      .sidebar { width: 230px; background: var(--mp-sidebar); color: var(--mp-sidebar-text); display: flex; flex-direction: column; }
      .brand { display: flex; align-items: center; gap: 10px; padding: 16px; border-bottom: 1px solid rgba(255,255,255,0.08); }
      .logo { width: 36px; height: 36px; border-radius: 8px; background: var(--mp-accent); color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 700; }
      .brand-name { font-weight: 600; color: #fff; }
      .brand-sub { font-size: 11px; color: var(--mp-sidebar-text); }
      .sidebar nav { padding: 10px; display: flex; flex-direction: column; gap: 2px; }
      .sidebar nav a { color: var(--mp-sidebar-text); text-decoration: none; padding: 9px 12px; border-radius: 6px; font-size: 13px; }
      .sidebar nav a:hover { background: rgba(255,255,255,0.06); color: #fff; }
      .sidebar nav a.active { background: var(--mp-accent); color: #fff; }
      .main { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
      .topbar { height: 52px; background: #fff; border-bottom: 1px solid var(--mp-border); display: flex; align-items: center; gap: 12px; padding: 0 20px; }
      .topbar-title { font-weight: 600; }
      .content { flex: 1; overflow: auto; padding: 20px; }
    `,
  ],
})
export class ShellComponent {
  constructor(public session: SessionService, private router: Router) {}

  logout(): void {
    this.session.logout();
    this.router.navigate(['/login']);
  }
}