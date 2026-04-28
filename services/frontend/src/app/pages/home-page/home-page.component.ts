import {Component, inject, OnInit} from '@angular/core';
import {OidcSecurityService} from "angular-auth-oidc-client";
import {Product} from "../../model/product";
import {ProductService} from "../../services/product/product.service";
import {AsyncPipe, JsonPipe} from "@angular/common";
import {Router} from "@angular/router";
import {Order} from "../../model/order";
import {FormsModule} from "@angular/forms";
import {OrderService} from "../../services/order/order.service";
import {filter, switchMap, take} from "rxjs";

@Component({
  selector: 'app-homepage',
  templateUrl: './home-page.component.html',
  standalone: true,
  imports: [AsyncPipe, JsonPipe, FormsModule],
  styleUrl: './home-page.component.css'
})
export class HomePageComponent implements OnInit {
  private readonly oidcSecurityService = inject(OidcSecurityService);
  private readonly productService = inject(ProductService);
  private readonly orderService = inject(OrderService);
  private readonly router = inject(Router);

  isAuthenticated = false;
  products: Array<Product> = [];
  quantityIsNull = false;
  orderSuccess = false;
  orderFailed = false;

  ngOnInit(): void {
    this.oidcSecurityService.isAuthenticated$.subscribe(
      ({isAuthenticated}) => {
        this.isAuthenticated = isAuthenticated;
      }
    );

    this.oidcSecurityService.isAuthenticated$
      .pipe(
        filter(({isAuthenticated}) => isAuthenticated),
        take(1),
        switchMap(() => this.productService.getProducts())
      )
      .subscribe({
        next: (products) => {
          this.products = products;
        },
        error: (err) => {
          console.error('Failed to load products', err);
        }
      });
  }

  goToCreateProductPage() {
    this.router.navigateByUrl('/add-product');
  }

  goToAddInventoryPage(): void {
    this.router.navigate(['/add-inventory']);
  }

  private getUserDetailsFromToken(): { email: string, firstName: string, lastName: string } {
    try {
      const storage = sessionStorage.length > 0 ? sessionStorage : localStorage;
      for (let i = 0; i < storage.length; i++) {
        const key = storage.key(i);
        if (key && (key.includes('access_token') || key.includes('accesstoken'))) {
          const raw = storage.getItem(key) as string;
          const tokenStr = raw.startsWith('"') ? JSON.parse(raw) : raw;
          if (tokenStr && (tokenStr as string).split('.').length === 3) {
            const parts = (tokenStr as string).split('.');
            const payload = JSON.parse(atob(parts[1])) as Record<string, any>;
            if (payload['email'] || payload['preferred_username']) {
              return {
                email: payload['email'] || payload['preferred_username'] || 'user@nexshop.com',
                firstName: payload['given_name'] || payload['name'] || 'User',
                lastName: payload['family_name'] || ''
              };
            }
          }
        }
      }
    } catch (e) {
      console.warn('Could not parse token', e);
    }
    return { email: 'user@nexshop.com', firstName: 'User', lastName: 'NexShop' };
  }

  orderProduct(product: Product, quantity: string) {
    if (!quantity) {
      this.orderFailed = true;
      this.orderSuccess = false;
      this.quantityIsNull = true;
      return;
    }

    this.orderFailed = false;
    this.orderSuccess = false;
    this.oidcSecurityService.getAccessToken().pipe(take(1)).subscribe(token => {
      let userDetails = { email: 'user@nexshop.com', firstName: 'User', lastName: 'NexShop' };
      if (token && typeof token === 'string' && token.split('.').length === 3) {
        try {
          const payload = JSON.parse(atob(token.split('.')[1])) as Record<string, any>;
          userDetails = {
            email: payload['email'] || payload['preferred_username'] || 'user@nexshop.com',
            firstName: payload['given_name'] || payload['name'] || 'User',
            lastName: payload['family_name'] || ''
          };
        } catch (e) { console.warn('token parse error', e); }
      }
      console.log('User details from token:', userDetails);

      const order: Order = {
        skuCode: product.skuCode,
        price: product.price,
        quantity: Number(quantity),
        userDetails: userDetails
      };

      this.orderService.orderProduct(order).subscribe({
        next: () => {
          this.orderSuccess = true;
          this.orderFailed = false;
          this.quantityIsNull = false;
        },
        error: () => {
          this.orderFailed = true;
          this.orderSuccess = false;
        }
      });
    });
  }
}
