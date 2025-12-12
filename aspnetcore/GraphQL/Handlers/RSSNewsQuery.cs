using rssnews.GraphQL.Repository;
using HotChocolate.Authorization;
using rssnews.Models;
using HotChocolate.Types.Pagination;

namespace rssnews.GraphQL.Handlers
{
    [GraphQLDescription("Provides RSS feed items with optional filtering by category.")]
    public class RSSNewsQuery
    {
        [Authorize]
        [GraphQLDescription("Gets a list of RSS items with optional filtering.")]
        [UsePaging(ConnectionName = "ItemConnection")]
        [UseFiltering] // เพิ่ม UseFiltering เพื่อรองรับการกรองเพิ่มเติมจาก HotChocolate
        [UseSorting]   // เพิ่ม UseSorting เพื่อรองรับการเรียงลำดับจาก HotChocolate
        public IQueryable<Item> GetRssItems(
            [Service] IItemService itemService,
            // ไม่ต้อง GraphQLType<IntType> สำหรับ int?
            int? categoryId = null)
        {
            if (categoryId.HasValue && categoryId.Value != 0)
            {
                // เรียกเมธอดที่ส่งคืน IQueryable<Item>
                return itemService.GetRSSItemByCategory(categoryId.Value);
            }
            else
            {
                // เรียกเมธอดที่ส่งคืน IQueryable<Item>
                return itemService.GetRSSItems();
            }
        }

        [GraphQLDescription("Gets a single RSS item by ID or slug.")]
        public async Task<Item?> GetRssItem(
            [Service] IItemService itemService,
            string? id = null)
        {
            if (!string.IsNullOrEmpty(id))
            {
                return await itemService.GetRSSItemById(id);
            }
            return null; // หรือจะโยน GraphQLException ถ้า id เป็น null/empty เพื่อความชัดเจน
        }

        [GraphQLDescription("Gets a list of all categories.")]
        public async Task<IEnumerable<Category>> GetCategories([Service] ICategoryService categoryService)
        {
            return await categoryService.GetCategories();
        }

        [GraphQLDescription("Gets a single category by ID.")]
        public async Task<Category?> GetCategory(
            [Service] ICategoryService categoryService,
            // ใน HotChocolate, NonNullType<IntType> จะถูกแมปกับ int โดยอัตโนมัติ
            // แต่การระบุ [GraphQLType<NonNullType<IntType>>] ชัดเจนก็ไม่ผิด
            int id)
        {
            return await categoryService.GetCategoryById(id);
        }

        [GraphQLDescription("Gets a list of all authors.")]
        public async Task<IEnumerable<Author>> GetAuthors([Service] IAuthorService authorService)
        {
            return await authorService.GetAuthors();
        }

        [GraphQLDescription("Gets a single author by Author ID.")]
        public async Task<Author?> GetAuthor(
            [Service] IAuthorService authorService,
            // ใน HotChocolate, NonNullType<StringType> จะถูกแมปกับ string โดยอัตโนมัติ
            // แต่การระบุ [GraphQLType<NonNullType<StringType>>] ชัดเจนก็ไม่ผิด
            string authorID)
        {
            return await authorService.GetAuthorById(authorID);
        }
    }

    // กำหนด PagingOptions เพื่อควบคุมพฤติกรรม Paging ทั่วไป
    public sealed class QueryPagingOptions : PagingOptions
    {
        public QueryPagingOptions()
        {
            DefaultPageSize = 20;
            MaxPageSize = 100;
            IncludeTotalCount = true;
        }
    }
}