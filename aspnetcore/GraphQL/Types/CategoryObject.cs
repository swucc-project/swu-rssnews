using rssnews.Models;

namespace rssnews.GraphQL.Types
{
    public sealed class CategoryObject : ObjectType<Category>
    {
        protected override void Configure(IObjectTypeDescriptor<Category> descriptor)
        {
            // ✅ ใช้ชื่อ "Category" ให้ตรงกับ Model
            descriptor.Name("Category");

            descriptor.Field(c => c.CategoryID)
                .Type<NonNullType<IntType>>()
                .Name("categoryID")
                .Description("The unique identifier of the category.");

            descriptor.Field(c => c.CategoryName)
                .Type<NonNullType<StringType>>()
                .Name("categoryName")
                .Description("The name of the category.");

            descriptor.Ignore(c => c.Items);
        }
    }
}