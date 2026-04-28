import {Injectable} from '@angular/core';
import {HttpClient} from "@angular/common/http";
import {Observable} from "rxjs";
import {Product} from "../../model/product";

@Injectable({
  providedIn: 'root'
})
export class ProductService {

  private apiUrl: string;

  constructor(private httpClient: HttpClient) {
    const env = (window as any).__ENV__ || {};
    this.apiUrl = env.API_GATEWAY_URL || 'http://localhost:30900';
  }

  getProducts(): Observable<Array<Product>> {
    return this.httpClient.get<Array<Product>>(`${this.apiUrl}/api/product`);
  }

  createProduct(product: Product): Observable<Product> {
    return this.httpClient.post<Product>(`${this.apiUrl}/api/product`, product);
  }
}
