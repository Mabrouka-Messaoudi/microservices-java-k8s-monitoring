import { Injectable } from '@angular/core';
import { Product } from "../../model/product";
import { Observable } from "rxjs";
import { HttpClient, HttpHeaders } from "@angular/common/http";
import { Order } from "../../model/order";

@Injectable({
  providedIn: 'root'
})
export class OrderService {

  private apiUrl: string;

  private httpOptions = {
    headers: new HttpHeaders({
      'Content-Type': 'application/json'
    })
  };

  constructor(private httpClient: HttpClient) {
    const env = (window as any).__ENV__ || {};
    this.apiUrl = env.API_GATEWAY_URL || 'http://localhost:30900';
  }

  orderProduct(order: Order): Observable<any> {
    return this.httpClient.post(
      `${this.apiUrl}/api/order`,
      order,
      { ...this.httpOptions, observe: 'response', responseType: 'text' as 'json' }
    );
  }
}
