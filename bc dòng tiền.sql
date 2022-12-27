set @end_date = date(date_add(curdate(), interval 7 hour ));
#Collection
with collections as
         (select*, concat('&&', code, '&&')
          from prod_product_service.collections
          where 1 = 1
            and is_deleted = 0)
select*
from collections;
#Tồn kho
with collections as
         (select*, concat('&&', code, '&&') as cl_code
          from prod_product_service.collections
          where 1 = 1
            and is_deleted = 0),
     inventories as
         (select store_id,
                 variant_id,
                 on_hand -- tồn
                 #, committed, available, in_coming, on_way, total_stock, on_hold, defect, transferring, shipping
          from prod_inventory_service.inventories
          where 1 = 1
            and is_deleted = 0
            and abs(on_hand) + abs(committed) + abs(available) + abs(in_coming) + abs(on_way) + abs(total_stock) +
                abs(on_hold) + abs(defect) + abs(transferring) + abs(shipping) > 0),
     sp as
         (select a.id,
                 upper(a.sku) sku,
                 a.name       variant_name,
                 cl.cl_code,
                 cl.name      collection_name,
                 p.name ,
                 p.category,
                 b.retail_price,
                 b.cost_price
          from prod_product_service.variant a
                   left join prod_product_service.variant_price b on a.id = b.variant_id
                   left join prod_product_service.product p on a.product_id = p.id
                   left join collections cl on cl.cl_code = p.collections
          where 1 = 1
            and a.is_deleted = 0
            and b.is_deleted = 0
            and left(a.sku, 1) <> 'Z'),
     kq as
         (select left(b.sku, 3)    ma3,
                 left(b.sku, 7)    ma7,
                 b.name,
                 b.cl_code collection_code,
                 b.collection_name,
                 b.category,
                 b.cost_price,
                 b.retail_price,
                 sum(a.on_hand) as on_hand -- tồn
                 #, a.committed, a.available, a.in_coming, a.on_way, a.total_stock, a.on_hold, a.defect, a.transferring, a.shipping
          from inventories a
                   join sp b on a.variant_id = b.id
          group by ma7),
     total as
         (select collection_code,
                 sum(on_hand * kq.cost_price) total_gt_ton #Giá trị tồn theo giá bán
          from kq
          group by collection_code),
     on_hand as
         (select *,
                 on_hand * kq.cost_price gt_ton #Giá trị tồn theo giá bán
          from kq
          group by ma7),
    ma7_onhand as
        (
            select oh.*,oh.gt_ton/tt.total_gt_ton tyle,tt.total_gt_ton
            from on_hand oh
            left join total tt on oh.collection_code=tt.collection_code
        ),
    order_line as
        (    select left(ol.sku, 7) ma7, sum(ol.quantity) quantity, sum(ol.line_amount_after_line_discount) total
             from prod_order_service.orders o
             join prod_order_service.order_line ol on o.id = ol.order_id
                 and
                 cast(date_add(o.finished_on, interval 7 hour) as date) between cast(date_add(@end_date, interval -7 day) as date) and @end_date
                 and o.status = 'finished'
                 and o.is_deleted = 0
                 and ol.order_id <> -1
             group by ma7
        )
    select m7.*, ol.quantity,ol.total
    from ma7_onhand m7
    left join order_line ol on m7.ma7=ol.ma7
;

