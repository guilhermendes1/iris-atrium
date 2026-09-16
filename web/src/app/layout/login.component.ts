import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { SessionService } from '../core/session.service';

@Component({
  selector: 'mp-login',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  template: `
    <div class="login-wrap">
      <div class="login-card">
        <h1>IRIS Atrium</h1>
        <p class="muted">Sign in with an IRIS username and password.</p>
        <div *ngIf="error" class="alert alert-error">{{ error }}</div>
        <form (ngSubmit)="submit()" #f="ngForm">
          <div class="form-row">
            <label for="username">Username</label>
            <input id="username" name="username" type="text" [(ngModel)]="username" required autofocus />
          </div>
          <div class="form-row">
            <label for="password">Password</label>
            <input id="password" name="password" type="password" [(ngModel)]="password" required />
          </div>
          <button type="submit" class="btn-primary" [disabled]="busy" style="width:100%">
            {{ busy ? 'Signing in...' : 'Sign in' }}
          </button>
        </form>
      </div>
    </div>
  `,
  styles: [
    `
      .login-wrap { display: flex; align-items: center; justify-content: center; height: 100vh; background: #1f2a38; }
      .login-card { background: #fff; border-radius: 10px; padding: 28px; width: 340px; box-shadow: 0 10px 40px rgba(0,0,0,0.25); }
      .login-card h1 { font-size: 18px; }
    `,
  ],
})
export class LoginComponent {
  username = '';
  password = '';
  busy = false;
  error = '';

  constructor(private session: SessionService, private router: Router) {}

  submit(): void {
    if (!this.username || !this.password) {
      this.error = 'Username and password are required.';
      return;
    }
    this.busy = true;
    this.error = '';
    this.session.login(this.username, this.password).subscribe({
      next: () => this.router.navigate(['/webapps']),
      error: () => {
        this.busy = false;
        this.error = 'Invalid username or password.';
      },
    });
  }
}