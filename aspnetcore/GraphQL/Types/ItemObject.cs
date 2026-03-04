using rssnews.GraphQL.Repository;
using rssnews.Models;

namespace rssnews.GraphQL.Types
{
    public sealed class ItemObject : ObjectType<Item>
    {
        protected override void Configure(IObjectTypeDescriptor<Item> descriptor)
        {
            // ✅ เปลี่ยนชื่อให้ตรงกับ Model หรือใช้ชื่อที่สื่อความหมาย
            descriptor.Name("Item");

            descriptor.Field(it => it.ItemID)
                .Type<NonNullType<StringType>>()
                .Description("The ID of the RSS item.")
                .Name("itemID");

            descriptor.Field(it => it.Title)
                .Type<NonNullType<StringType>>()
                .Description("The title of the RSS item.")
                .Name("title");

            descriptor.Field(it => it.Link)
                .Type<NonNullType<StringType>>()
                .Description("The link to the RSS item content.")
                .Name("link");

            descriptor.Field(it => it.Description)
                .Type<NonNullType<StringType>>()
                .Description("The description of the RSS item.")
                .Name("description");

            descriptor.Field(it => it.PublishedDate)
                .Type<NonNullType<DateTimeType>>()
                .Description("The publication date of the RSS item.")
                .Name("publishedDate");

            descriptor.Field(it => it.CategoryID)
                .Type<NonNullType<IntType>>()
                .Description("The ID of the category.")
                .Name("categoryID");

            descriptor.Field(it => it.AuthorID)
                .Type<NonNullType<StringType>>()
                .Description("The ID of the author.")
                .Name("authorBuasriID");

            // ✅ แก้ไขตรงนี้: ใช้ CategoryObject โดยตรง ไม่ต้องครอบ ObjectType
            descriptor.Field("category")
                .Type<CategoryObject>()  // ✅ ถูกต้อง
                .ResolveWith<ItemResolvers>(r => r.GetCategory(default!, default!))
                .Description("The category of the RSS item.");

            // ✅ แก้ไขตรงนี้: ใช้ AuthorObject โดยตรง
            descriptor.Field("author")
                .Type<AuthorObject>()  // ✅ ถูกต้อง
                .ResolveWith<ItemResolvers>(r => r.GetAuthor(default!, default!))
                .Description("The author of the RSS item.");
        }
    }
    public class ItemResolvers
    {
        public async Task<Category?> GetCategory([Parent] Item item, [Service] ICategoryService categoryService)
        {
            return await categoryService.GetCategoryById(item.CategoryID);
        }

        public async Task<Author?> GetAuthor([Parent] Item item, [Service] IAuthorService authorService)
        {
            return await authorService.GetAuthorById(item.AuthorID);
        }
    }
}