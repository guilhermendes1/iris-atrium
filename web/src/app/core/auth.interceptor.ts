import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { SessionService } from './session.service';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const session = inject(SessionService);
  const token = session.token;
  if (token) {
    const headers = req.headers.set('Authorization', `Basic ${token}`);
    return next(req.clone({ headers }));
  }
  return next(req);
};